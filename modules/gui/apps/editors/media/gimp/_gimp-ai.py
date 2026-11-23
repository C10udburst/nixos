#!@aiInterpreter@
# GIMP AI -- server-backed image generation and editing (Filters > AI).
#
# Talks to an OpenAI-compatible image server (gufo-image / Qwen-Image):
#   GET  {base}/v1/models              -> filtered to "images" in capabilities
#   POST {base}/v1/images/generations  -> JSON body, result in .data[0].b64_json
#   POST {base}/v1/images/edits        -> multipart form (image[] + background)
#
# Backend URL and the python interpreter are substituted by the Nix module
# (pkgs.substituteAll placeholders below).
#
# The model only produces images on a fixed set of canvases (ASPECT_SIZES).
# When editing, the active layer's selected region (or the whole image) is
# contain-scaled onto the canvas whose aspect ratio is closest, padded with
# fully transparent pixels, and sent to the server, which supports
# transparent output. The exact inverse transformations (crop padding, scale
# back) are applied to the returned image before it is inserted as a new
# layer above the source layer, so the result blends back in seamlessly.

import base64
import json
import math
import os
import sys
import tempfile
import threading
import urllib.error
import urllib.request
import uuid

import gi

gi.require_version("Gimp", "3.0")
from gi.repository import Gimp
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, GObject, Gtk

BACKEND_URL = "@aiBackendUrl@".rstrip("/")
MODELS_TIMEOUT = 30
GENERATE_TIMEOUT = 900

# Canvas sizes per aspect ratio. These are the recommended pixel sizes for
# qwen-image-2.1 and qwen-image-2.1-turbo and are reused as a sane fallback
# for any other image model the backend may expose.
ASPECT_SIZES = {
    "1:1": (2048, 2048),
    "4:3": (2400, 1792),
    "3:4": (1792, 2400),
    "3:2": (2528, 1696),
    "2:3": (1696, 2528),
    "16:9": (2752, 1536),
    "9:16": (1536, 2752),
}

# Hardcoded model -> size map. Extend here for models that differ.
MODEL_SIZES = {
    "qwen-image-2.1": ASPECT_SIZES,
    "qwen-image-2.1-turbo": ASPECT_SIZES,
}

EDIT_PROMPT = """Edit the picture as described below.

CRITICAL CONSTRAINTS: this image is only a crop of a larger picture and it is
padded with fully transparent margins. Keep the alpha channel intact and keep
the outermost border rows/columns of pixels EXACTLY as they are: do not move,
stretch, rotate, blur, recolor or repaint anything inside a few-pixel border
of the image, do not extend content into the transparent margins, and do not
fill in transparent areas. The result must blend back seamlessly at the edges.

Editing instruction: """


class AIError(Exception):
    pass


def N_(message):
    return message


def _(message):
    return GLib.dgettext(None, message)


def sizes_for_model(model):
    return MODEL_SIZES.get((model or "").lower().strip(), ASPECT_SIZES)


def best_ratio(w, h, sizes):
    """Aspect-ratio key whose canvas is closest (in log space) to w/h."""
    aspect = float(w) / float(h)
    return min(sizes, key=lambda r: abs(math.log(aspect) - math.log(sizes[r][0] / sizes[r][1])))


def fit(w, h, tw, th):
    """Largest in-aspect scale of w*h that fits into tw*th, plus centered padding."""
    scale = min(tw / float(w), th / float(h))
    sw = max(1, min(tw, int(round(w * scale))))
    sh = max(1, min(th, int(round(h * scale))))
    pad_x = (tw - sw) // 2
    pad_y = (th - sh) // 2
    return sw, sh, pad_x, pad_y, scale


# ──────────────────────────────────────────────────────────────────────────
# HTTP helpers
# ──────────────────────────────────────────────────────────────────────────

def http_json(url, data=None, headers=None, timeout=MODELS_TIMEOUT):
    request = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", "replace")[:600]
        except Exception:
            pass
        raise AIError(f"HTTP {e.code} from {url}\n{body}") from e
    except urllib.error.URLError as e:
        raise AIError(f"Cannot reach {url}: {e.reason}") from e


def list_image_models():
    payload = http_json(BACKEND_URL + "/v1/models")
    return sorted(
        m["id"]
        for m in payload.get("data", [])
        if isinstance(m, dict) and "images" in (m.get("capabilities") or []) and m.get("id")
    )


def pixbuf_from_b64(b64):
    raw = base64.b64decode(b64)
    stream = GLib.MemoryInputStream.new_from_bytes(GLib.Bytes.new(raw))
    pixbuf = GdkPixbuf.Pixbuf.new_from_stream(stream)
    stream.close()
    if pixbuf is None:
        raise AIError("the server replied with something that is not a valid PNG image")
    return pixbuf


def extract_b64(payload):
    try:
        return payload["data"][0]["b64_json"]
    except (KeyError, IndexError, TypeError) as e:
        raise AIError(f"unexpected server response: {str(payload)[:300]}") from e


def server_generate(model, prompt, width, height):
    body = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "size": f"{width}x{height}",
            "n": 1,
            "background": "transparent",
        }
    ).encode("utf-8")
    payload = http_json(
        BACKEND_URL + "/v1/images/generations",
        data=body,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        timeout=GENERATE_TIMEOUT,
    )
    return pixbuf_from_b64(extract_b64(payload))


def multipart_body(fields, filename, content_type, blob):
    boundary = "gimpAIBoundary" + uuid.uuid4().hex
    out = []
    for key, value in fields:
        out.append(f"--{boundary}")
        out.append(f'Content-Disposition: form-data; name="{key}"')
        out.append("")
        out.append(value)
    out.append(f"--{boundary}")
    out.append(f'Content-Disposition: form-data; name="image[]"; filename="{filename}"')
    out.append(f"Content-Type: {content_type}")
    out.append("")
    head = "\r\n".join(out).encode("utf-8") + b"\r\n"
    tail = f"\r\n--{boundary}--\r\n".encode("utf-8")
    return head + blob + tail, boundary


def server_edit(model, prompt, png_bytes, width, height):
    fields = [
        ("model", model),
        ("prompt", prompt),
        ("size", f"{width}x{height}"),
        ("background", "transparent"),
    ]
    body, boundary = multipart_body(fields, "image.png", "image/png", png_bytes)
    payload = http_json(
        BACKEND_URL + "/v1/images/edits",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        timeout=GENERATE_TIMEOUT,
    )
    return pixbuf_from_b64(extract_b64(payload))


# ──────────────────────────────────────────────────────────────────────────
# Image plumbing (layers, selections, scaling, padding)
# ──────────────────────────────────────────────────────────────────────────

def selection_rect(image):
    """(x, y, w, h) bounding box of the selection, or None when empty."""
    try:
        if Gimp.Selection.is_empty(image):
            return None
        values = list(Gimp.Selection.bounds(image))
        if len(values) == 6:  # (success, non_empty, x1, y1, x2, y2)
            _, non_empty, x1, y1, x2, y2 = values
        elif len(values) == 5:  # (non_empty, x1, y1, x2, y2)
            non_empty, x1, y1, x2, y2 = values
        else:
            return None
        if not non_empty:
            return None
        x1 = max(0, min(x1, image.get_width()))
        y1 = max(0, min(y1, image.get_height()))
        x2 = max(0, min(x2, image.get_width()))
        y2 = max(0, min(y2, image.get_height()))
        if x2 - x1 < 1 or y2 - y1 < 1:
            return None
        return (x1, y1, x2 - x1, y2 - y1)
    except Exception:
        return None


def pixbuf_rgba8(pixbuf):
    if pixbuf.get_bits_per_sample() != 8 or pixbuf.get_colorspace() != GdkPixbuf.Colorspace.RGB:
        pixbuf = pixbuf.convert(GdkPixbuf.Colorspace.RGB, True, 8)
    if not pixbuf.get_has_alpha():
        pixbuf = pixbuf.add_alpha(False, 0, 0, 0)
    return pixbuf


def layer_region_pixbuf(layer, x, y, w, h):
    """Exact 1:1 RGBA pixels of an image-space rectangle of `layer`."""
    off_x, off_y = layer.get_offsets()
    pixbuf = layer.get_sub_thumbnail(
        x - off_x,
        y - off_y,
        w,
        h,
        w,
        h,
        Gimp.PixbufTransparency.KEEP_ALPHA,
    )
    if pixbuf is None:
        raise AIError("could not read the pixels of the active layer")
    return pixbuf_rgba8(pixbuf)


def pixbuf_png_bytes(pixbuf):
    fd, path = tempfile.mkstemp(prefix="gimp-ai-", suffix=".png")
    os.close(fd)
    try:
        if not pixbuf.savev(path, "png", [], []):
            raise AIError("failed to encode the image as PNG")
        with open(path, "rb") as f:
            return f.read()
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def edit_plan(w, h, model):
    """Pick the least-distorting canvas and the contain-scale + padding plan."""
    sizes = sizes_for_model(model)
    ratio = best_ratio(w, h, sizes)
    tw, th = sizes[ratio]
    sw, sh, pad_x, pad_y, scale = fit(w, h, tw, th)
    return {
        "ratio": ratio,
        "target": (tw, th),
        "scaled": (sw, sh),
        "pad": (pad_x, pad_y),
        "scale": scale,
    }


def build_edit_upload(layer, rect, model):
    """Scale + transparent-pad the region; returns (png bytes, plan dict)."""
    x, y, w, h = rect
    plan = edit_plan(w, h, model)
    tw, th = plan["target"]
    sw, sh = plan["scaled"]

    region = layer_region_pixbuf(layer, x, y, w, h)
    scaled = region.scale_simple(sw, sh, GdkPixbuf.InterpType.HIGH) if (sw, sh) != (w, h) else region

    canvas = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, tw, th)
    canvas.fill(0)  # fully transparent padding
    scaled.copy_area(0, 0, sw, sh, canvas, pad_x, pad_y)

    plan["rect"] = rect
    return pixbuf_png_bytes(canvas), plan


def inverse_transform(pixbuf, plan):
    """Undo padding + scaling on the server's answer."""
    tw, th = plan["target"]
    sw, sh = plan["scaled"]
    pad_x, pad_y = plan["pad"]
    _, _, w, h = plan["rect"]

    if (pixbuf.get_width(), pixbuf.get_height()) != (tw, th):
        pixbuf = pixbuf.scale_simple(tw, th, GdkPixbuf.InterpType.HIGH)
    sub = pixbuf.new_subpixbuf(pad_x, pad_y, sw, sh)
    result = sub.scale_simple(w, h, GdkPixbuf.InterpType.HIGH) if (sw, sh) != (w, h) else sub.copy()
    return pixbuf_rgba8(result)


def add_generated_layer(image, ref_item, pixbuf, name, offset_x, offset_y):
    layer = Gimp.Layer.new_from_pixbuf(
        image, name, pixbuf, 100.0, Gimp.LayerMode.NORMAL, 0.0, 100.0
    )
    image.undo_group_start()
    try:
        image.insert_layer(layer, ref_item.get_parent(), image.get_item_position(ref_item))
        layer.set_offsets(offset_x, offset_y)
        try:
            image.set_selected_layers([layer])
        except Exception:
            pass
    finally:
        image.undo_group_end()
    Gimp.displays_flush()


# ──────────────────────────────────────────────────────────────────────────
# Spinner dialog (blocks, but the user can press "Background")
# ──────────────────────────────────────────────────────────────────────────

def run_with_spinner(heading, detail, work):
    """Run `work()` on a worker thread behind a spinner dialog.

    Pressing "Background" hides the dialog while the request keeps running;
    the result is applied in both cases once it arrives. Returns the worker
    result or raises AIError.
    """
    loop = GLib.MainLoop()
    state = {"result": None, "error": None, "done": False}

    dialog = Gtk.Dialog(title="AI", flags=Gtk.DialogFlags.MODAL)
    dialog.add_button(_("_Background"), Gtk.ResponseType.CLOSE)
    dialog.set_default_size(440, -1)

    content = dialog.get_content_area()
    content.set_spacing(8)
    content.set_border_width(12)

    heading_label = Gtk.Label()
    heading_label.set_markup(f"<b>{GLib.markup_escape_text(heading)}</b>")
    heading_label.set_line_wrap(True)
    heading_label.set_xalign(0.0)
    content.pack_start(heading_label, False, False, 0)

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    spinner = Gtk.Spinner()
    box.pack_start(spinner, False, False, 0)
    detail_label = Gtk.Label(label=detail)
    detail_label.set_line_wrap(True)
    detail_label.set_xalign(0.0)
    box.pack_start(detail_label, True, True, 0)
    content.pack_start(box, True, True, 0)

    hint = Gtk.Label()
    hint.set_markup(
        "<small>Image generation can take a while. <b>Background</b> hides "
        "this dialog; the new layer will appear in the image as soon as the "
        "answer arrives.</small>"
    )
    hint.set_line_wrap(True)
    hint.set_xalign(0.0)
    content.pack_start(hint, False, False, 0)

    dialog.show_all()
    spinner.start()

    def finish():
        state["done"] = True
        try:
            if dialog.get_visible():
                dialog.response(Gtk.ResponseType.OK)
        except Exception:
            pass
        try:
            if loop.is_running():
                loop.quit()
        except Exception:
            pass
        return False

    def worker():
        try:
            state["result"] = work()
        except AIError as e:
            state["error"] = e
        except Exception as e:  # noqa: BLE001
            state["error"] = AIError(str(e))
        GLib.idle_add(finish)

    threading.Thread(target=worker, daemon=True).start()

    dialog.run()  # returns when Background is pressed, or when finish() responds
    spinner.stop()
    dialog.destroy()

    if not state["done"]:
        loop.run()  # keep serving the main context while working in background

    if state["error"] is not None:
        raise state["error"]
    return state["result"]


# ──────────────────────────────────────────────────────────────────────────
# Option dialog widgets
# ──────────────────────────────────────────────────────────────────────────

class PromptView(Gtk.ScrolledWindow):
    def __init__(self, text="", width=460, height=110):
        super().__init__()
        self.set_size_request(width, height)
        self.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.view = Gtk.TextView()
        self.view.set_wrap_mode(Gtk.WrapMode.WORD)
        buffer = self.view.get_buffer()
        if text:
            buffer.set_text(text)
        else:
            try:
                self.view.set_placeholder_text("Describe the image…")
            except Exception:
                pass
        self.add(self.view)

    def get_text(self):
        buffer = self.view.get_buffer()
        return buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter(), True).strip()


class ModelPicker(Gtk.Box):
    """ComboBoxText populated with image-capable models + a refresh button."""

    def __init__(self, on_change=None):
        super().__init__(spacing=6)
        self.on_change = on_change
        self.pack_start(Gtk.Label(label=_("Model:")), False, False, 0)
        self.combo = Gtk.ComboBoxText()
        self.combo.set_hexpand(True)
        self.combo.connect("changed", lambda _c: self.on_change and self.on_change(self.get_model()))
        self.pack_start(self.combo, True, True, 0)
        refresh = Gtk.Button(label=_("Refresh"))
        refresh.connect("clicked", lambda _b: self.reload())
        self.pack_start(refresh, False, False, 0)
        self.status = Gtk.Label(label="")
        self.status.set_line_wrap(True)
        self.status.set_xalign(0.0)
        self.reload()

    def reload(self):
        self.combo.remove_all()
        try:
            models = list_image_models()
            self.status.set_text("")
        except Exception as e:  # noqa: BLE001
            models = []
            self.status.set_text(f"Cannot list models: {e}")
        for model in models:
            self.combo.append_text(model)
        if models:
            self.combo.set_active(0)

    def get_model(self):
        return self.combo.get_active_text() or ""

    def has_models(self):
        return self.combo.get_active() >= 0


def describe_edit_plan(image, layer, rect, model):
    """Human readable description of every transformation the edit will do."""
    x, y, w, h = rect
    plan = edit_plan(w, h, model)
    tw, th = plan["target"]
    sw, sh = plan["scaled"]
    pad_x, pad_y = plan["pad"]
    scale = plan["scale"]
    ratio = plan["ratio"]

    esc = GLib.markup_escape_text
    try:
        layer_name = layer.get_name()
    except Exception:
        layer_name = "?"
    alpha = ", with alpha" if layer.has_alpha() else ""
    full_image = rect == (0, 0, image.get_width(), image.get_height())

    lines = [
        f"<b>Source</b> — layer “{esc(layer_name)}”{alpha}, "
        + ("whole image (no selection)" if full_image else f"selection {w}×{h} px at ({x}, {y})")
    ]
    if model:
        lines.append(
            f"<b>Target</b> — closest ratio to {w / h:.3f} is {ratio} "
            f"→ {tw}×{th} px canvas of “{esc(model)}”"
        )
    arrow = "upscale" if scale > 1.001 else "downscale" if scale < 0.999 else "scale"
    lines.append(
        f"<b>Upload</b> — {arrow} ×{scale:.3f} to {sw}×{sh}, then pad "
        f"left {pad_x} / right {tw - sw - pad_x} / top {pad_y} / bottom "
        f"{th - sh - pad_y} px transparent → exactly {tw}×{th} px sent"
    )
    lines.append(
        f"<b>Result</b> — crop the padding off, scale back to {w}×{h}, "
        f"insert at ({x}, {y}) as a new layer “Generated {esc(model)}” above "
        "the source layer (server keeps transparency for blending)"
    )
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────
# Procedure plugin
# ──────────────────────────────────────────────────────────────────────────

class GimpAI(Gimp.PlugIn):
    # No gettext catalogs are shipped with this plug-in; without this override
    # GIMP prints "The catalog directory does not exist ..." for every
    # registered procedure on start-up.
    def do_set_i18n(self, procname):
        return False, None, None

    def do_query_procedures(self):
        return ["gimp-ai-generate", "gimp-ai-edit"]

    def do_create_procedure(self, name):
        procedure = Gimp.ImageProcedure.new(
            self,
            name,
            Gimp.PDBProcType.PLUGIN,
            self.run_generate if name == "gimp-ai-generate" else self.run_edit,
            None,
        )
        procedure.set_image_types("*")
        procedure.set_sensitivity_mask(
            Gimp.ProcedureSensitivityMask.DRAWABLE | Gimp.ProcedureSensitivityMask.DRAWABLES
        )
        procedure.set_attribution("cloudburst", "gimp-ai", "2025")
        if name == "gimp-ai-generate":
            procedure.set_menu_label(_("_Image Generate..."))
            procedure.set_documentation(
                _("Generate an image with the AI backend"),
                _("Generate an image from a text prompt on the configured "
                  "OpenAI-compatible backend and add it as a new layer."),
                name,
            )
            procedure.add_menu_path("<Image>/Filters/AI")
            procedure.add_string_argument("prompt", _("Prompt"), _("Prompt text"), "", GObject.ParamFlags.READWRITE)
            procedure.add_string_argument("model", _("Model"), _("Image model id"), "", GObject.ParamFlags.READWRITE)
            procedure.add_string_argument("ratio", _("Aspect ratio"), _("Aspect ratio key, e.g. 16:9"), "1:1", GObject.ParamFlags.READWRITE)
        else:
            procedure.set_menu_label(_("_Image Edit..."))
            procedure.set_documentation(
                _("Edit the selection (or whole image) with the AI backend"),
                _("Take the active layer's selected region, scale and pad it "
                  "to the least-distorting model canvas, edit it on the "
                  "configured backend, and paste the inverse-transformed "
                  "answer back as a new layer."),
                name,
            )
            procedure.add_menu_path("<Image>/Filters/AI")
            procedure.add_string_argument("prompt", _("Prompt"), _("Prompt text"), EDIT_PROMPT, GObject.ParamFlags.READWRITE)
            procedure.add_string_argument("model", _("Model"), _("Image model id"), "", GObject.ParamFlags.READWRITE)
        return procedure

    # ── helpers ──────────────────────────────────────────────────────────

    def _reference_item(self, image, drawables):
        for item in drawables or []:
            try:
                if item.is_layer():
                    return item
            except Exception:
                continue
        layers = image.get_layers()
        if layers:
            return layers[0]
        raise AIError("this image has no layers to work with")

    def _cancelled(self, procedure):
        return procedure.new_return_values(Gimp.PDBStatusType.CANCEL, GLib.Error())

    def _failed(self, procedure, error):
        return procedure.new_return_values(
            Gimp.PDBStatusType.EXECUTION_ERROR, GLib.Error(str(error))
        )

    # ── procedures ───────────────────────────────────────────────────────

    def run_generate(self, procedure, run_mode, image, drawables, config, data):
        try:
            ref = self._reference_item(image, drawables)
            interactive = run_mode != Gimp.RunMode.NONINTERACTIVE

            if interactive:
                picked = self._generate_dialog(image)
                if picked is None:
                    return self._cancelled(procedure)
                model, prompt, ratio = picked
            else:
                model = config.get_property("model")
                prompt = config.get_property("prompt")
                ratio = config.get_property("ratio")
                if not model or not prompt:
                    return procedure.new_return_values(
                        Gimp.PDBStatusType.CALLING_ERROR,
                        GLib.Error("both 'model' and 'prompt' are required"),
                    )
                if ratio not in sizes_for_model(model):
                    ratio = best_ratio(
                        image.get_width(), image.get_height(), sizes_for_model(model)
                    )

            width, height = sizes_for_model(model)[ratio]
            config.set_property("model", model)
            config.set_property("prompt", prompt)
            config.set_property("ratio", ratio)

            if interactive:
                pixbuf = run_with_spinner(
                    f"Generating {width}×{height} with “{model}”",
                    "Waiting for the server…",
                    lambda: server_generate(model, prompt, width, height),
                )
            else:
                pixbuf = server_generate(model, prompt, width, height)

            offset_x = (image.get_width() - pixbuf.get_width()) // 2
            offset_y = (image.get_height() - pixbuf.get_height()) // 2
            add_generated_layer(
                image, ref, pixbuf_rgba8(pixbuf), f"Generated {model}", offset_x, offset_y
            )
            return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())
        except AIError as e:
            return self._failed(procedure, e)

    def run_edit(self, procedure, run_mode, image, drawables, config, data):
        try:
            ref = self._reference_item(image, drawables)
            rect = selection_rect(image) or (0, 0, image.get_width(), image.get_height())
            interactive = run_mode != Gimp.RunMode.NONINTERACTIVE

            if interactive:
                picked = self._edit_dialog(image, ref, rect)
                if picked is None:
                    return self._cancelled(procedure)
                model, prompt = picked
            else:
                model = config.get_property("model")
                prompt = config.get_property("prompt")
                if not model or not prompt:
                    return procedure.new_return_values(
                        Gimp.PDBStatusType.CALLING_ERROR,
                        GLib.Error("both 'model' and 'prompt' are required"),
                    )

            config.set_property("model", model)
            config.set_property("prompt", prompt)

            def work():
                png, plan = build_edit_upload(ref, rect, model)
                answer = server_edit(model, prompt, png, *plan["target"])
                return answer, plan

            if interactive:
                answer, plan = run_with_spinner(
                    f"Editing {rect[2]}×{rect[3]} px with “{model}”",
                    f"Uploading to the {edit_plan(rect[2], rect[3], model)['ratio']} "
                    f"canvas ({plan_size_note(rect, model)})…",
                    work,
                )
            else:
                answer, plan = work()

            result = inverse_transform(answer, plan)
            add_generated_layer(image, ref, result, f"Generated {model}", rect[0], rect[1])
            return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())
        except AIError as e:
            return self._failed(procedure, e)

    # ── dialogs ──────────────────────────────────────────────────────────

    def _generate_dialog(self, image):
        dialog = Gtk.Dialog(title=_("AI — Image Generate"), flags=Gtk.DialogFlags.MODAL)
        cancel = dialog.add_button(_("_Cancel"), Gtk.ResponseType.CANCEL)
        run_button = dialog.add_button(_("_Generate"), Gtk.ResponseType.OK)

        grid = Gtk.Grid(column_spacing=8, row_spacing=8, border_width=12)
        dialog.get_content_area().pack_start(grid, True, True, 0)

        ratios = Gtk.ComboBoxText()
        ratios.set_hexpand(True)
        prompt = PromptView()

        def refresh_ratios(model):
            target = sizes_for_model(model)
            ratios.remove_all()
            for key, (w, h) in target.items():
                ratios.append(key, f"{key}  ({w}×{h})")
            default = best_ratio(image.get_width(), image.get_height(), target)
            ratios.set_active_id(default)

        def update_ok(*_args):
            try:
                run_button.set_sensitive(
                    models.has_models()
                    and bool(prompt.get_text())
                    and ratios.get_active_id() is not None
                )
            except Exception:
                pass

        models = ModelPicker(on_change=lambda model: (refresh_ratios(model), update_ok()))

        refresh_ratios(models.get_model())
        models.combo.connect("changed", update_ok)
        prompt.view.get_buffer().connect("changed", update_ok)
        update_ok()

        row = 0
        grid.attach(models, 0, row, 2, 1)
        row += 1
        grid.attach(models.status, 0, row, 2, 1)
        row += 1
        grid.attach(Gtk.Label(label=_("Prompt:")), 0, row, 2, 1)
        row += 1
        prompt.set_hexpand(True)
        grid.attach(prompt, 0, row, 2, 1)
        row += 1
        grid.attach(Gtk.Label(label=_("Aspect ratio / size:")), 0, row, 1, 1)
        grid.attach(ratios, 1, row, 1, 1)

        dialog.show_all()
        response = dialog.run()
        result = None
        if response == Gtk.ResponseType.OK:
            result = (models.get_model(), prompt.get_text(), ratios.get_active_id())
        dialog.destroy()
        return result

    def _edit_dialog(self, image, ref, rect):
        dialog = Gtk.Dialog(title=_("AI — Image Edit"), flags=Gtk.DialogFlags.MODAL)
        cancel = dialog.add_button(_("_Cancel"), Gtk.ResponseType.CANCEL)
        run_button = dialog.add_button(_("_Edit"), Gtk.ResponseType.OK)

        content = dialog.get_content_area()
        content.set_spacing(8)
        content.set_border_width(12)

        grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        content.pack_start(grid, True, True, 0)

        prompt = PromptView(text=EDIT_PROMPT, height=150)
        prompt.set_hexpand(True)
        # The prompt soaks up all the slack, which keeps the transformation
        # summary glued to the bottom of the content area, i.e. right above the
        # Cancel / Edit buttons.
        prompt.set_vexpand(True)

        info = Gtk.Label()
        info.set_use_markup(True)
        info.set_line_wrap(True)
        info.set_xalign(0.0)
        info.set_selectable(True)
        info.set_margin_start(6)
        info.set_margin_end(6)
        info.set_margin_top(6)
        info.set_margin_bottom(6)
        frame = Gtk.Frame()
        frame.set_shadow_type(Gtk.ShadowType.IN)
        frame.add(info)

        def update_ok(*_args):
            try:
                run_button.set_sensitive(models.has_models() and bool(prompt.get_text()))
            except Exception:
                pass

        def update_info(model):
            if model:
                info.set_markup(describe_edit_plan(image, ref, rect, model))
            update_ok()

        models = ModelPicker(on_change=update_info)
        prompt.view.get_buffer().connect("changed", update_ok)

        grid.attach(models, 0, 0, 2, 1)
        grid.attach(models.status, 0, 1, 2, 1)
        grid.attach(Gtk.Label(label=_("Prompt:")), 0, 2, 2, 1)
        grid.attach(prompt, 0, 3, 2, 1)

        # Packed from the end of the (vertical) content area, so the summary is
        # the last thing before the dialog buttons.
        summary = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        summary.pack_start(Gtk.Label(label=_("Planned transformations:")), False, False, 0)

        frame.set_hexpand(True)
        frame.set_valign(Gtk.Align.START)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_propagate_natural_height(True)
        scrolled.set_max_content_height(220)
        scrolled.set_vexpand(False)
        scrolled.add(frame)
        summary.pack_start(scrolled, False, False, 0)

        content.pack_end(summary, False, False, 0)

        update_info(models.get_model())
        dialog.show_all()
        response = dialog.run()
        result = None
        if response == Gtk.ResponseType.OK:
            result = (models.get_model(), prompt.get_text())
        dialog.destroy()
        return result


def plan_size_note(rect, model):
    try:
        tw, th = edit_plan(rect[2], rect[3], model)["target"]
        return f"{tw}×{th} px"
    except Exception:
        return "server canvas"


Gimp.main(GimpAI.__gtype__, sys.argv)
