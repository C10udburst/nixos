"""Metadata resolution for the LiteLLM config generator.

Third-party imports are kept out of module level (requests is imported lazily in
load_pricing) so this stays importable and checkable with a bare python3.
"""

PRICING_URL = (
    "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
)

model_pricing = {}


def load_pricing(timeout=10):
    """Fill model_pricing from litellm's live map; stays {} when offline."""
    global model_pricing
    import requests

    try:
        resp = requests.get(PRICING_URL, timeout=timeout)
        if resp.ok:
            model_pricing = resp.json()
    except Exception as e:
        print(f"Pricing fetch error: {e}")
    return model_pricing


def get_anyof(d, keys, default=None):
    if not isinstance(d, dict):
        return default
    for key in keys:
        if key in d:
            return d[key]
        if "." in key:
            parts = key.split(".")
            sub_d = d
            found = True
            for part in parts:
                if isinstance(sub_d, dict) and part in sub_d:
                    sub_d = sub_d[part]
                else:
                    found = False
                    break
            if found:
                return sub_d
    return default


# Field names each provider actually uses for its token limits. Provider-native names come
# first so they win over aliases. Unknown limits are left unset rather than defaulting to
# 2048/1024: that bogus default is written into model_info and overrides litellm's own,
# correct, map entry.
CTX_KEYS = [
    "max_input_tokens",
    "context_window_size",             # vLLM / LM Studio
    "max_model_len",                   # vLLM
    "context_window",                  # Groq
    "context_length",                  # OpenRouter / Ollama
    "max_context_length",
    "max_position_embeddings",
    "num_ctx",                         # Ollama
    "top_provider.context_length",     # OpenRouter
    "architecture.context_window_size",
    "inputTokenLimit",                 # Google
]
OUT_KEYS = [
    "max_output_tokens",
    "max_completion_tokens",           # Groq / OpenRouter
    "max_output_length",               # Groq
    "top_provider.max_completion_tokens",
    "architecture.max_output_tokens",
    "outputTokenLimit",                # Google
]


def merge_dicts(a, b):
    if not isinstance(b, dict):
        return a
    for key, value in b.items():
        if key not in a:
            a[key] = value
    return a


def to_list(val):
    if val is None:
        return []
    if isinstance(val, (list, set, tuple)):
        return list(val)
    return [val]


def model_info(model, extra=None):
    # extra: per-deployment metadata absent from the model object itself,
    # e.g. HuggingFace keeps context_length on providers[], not on the model.
    try:
        mid = get_anyof(model, ["id", "name"]) or ""
        ids = [mid]
        if "/" in model.get("id", ""):
            ids.append(model["id"].split("/")[-1])
        ids = set(
            ids
            + [m.split(":")[0] for m in ids if ":" in m]
            + [m.removeprefix("model/") for m in ids if m.startswith("model/")]
        )
        pricing = {}
        for m in ids:
            if m in model_pricing:
                pricing = model_pricing[m]
                break

        info = {}
        modalities_in = (
            get_anyof(
                model,
                [
                    "input_modalities",
                    "supported_input_modalities",
                    "modalities",
                    "supported_modalities",
                    "architecture.input_modalities",
                ],
            )
            or get_anyof(
                pricing,
                [
                    "input_modalities",
                    "supported_input_modalities",
                    "modalities",
                    "supported_modalities",
                ],
            )
            or []
        )
        modalities_out = (
            get_anyof(
                model,
                [
                    "output_modalities",
                    "supported_output_modalities",
                    "architecture.output_modalities",
                    "supportedGenerationMethods",
                ],
            )
            or get_anyof(pricing, ["output_modalities", "supported_output_modalities"])
            or modalities_in
        )
        description = (
            get_anyof(model, ["description", "model_description", "summary"])
            or get_anyof(pricing, ["description", "model_description", "summary"])
            or ""
        )
        def _to_int(val):
            if val is None:
                return None
            try:
                return int(val)
            except (ValueError, TypeError):
                return val

        max_input_tokens = _to_int(
            get_anyof(extra, CTX_KEYS) or get_anyof(model, CTX_KEYS) or get_anyof(pricing, CTX_KEYS)
        )
        max_output_tokens = _to_int(
            get_anyof(extra, OUT_KEYS) or get_anyof(model, OUT_KEYS) or get_anyof(pricing, OUT_KEYS)
        )
        max_tokens = _to_int(
            get_anyof(extra, ["max_tokens"])
            or get_anyof(model, ["max_tokens"])
            or get_anyof(pricing, ["max_tokens"])
            or max_output_tokens
            or max_input_tokens
        )

        in_set = set(to_list(modalities_in))
        out_set = set(to_list(modalities_out))
        if get_anyof(model, ["image"]):
            out_set.add("image")
        if get_anyof(model, ["vision"]):
            in_set.add("image")
        if "generateContent" in out_set:
            out_set.add("text")

        info["modalities"] = sorted(list(in_set | out_set))
        info["description"] = description
        info["input_modalities"] = sorted(list(in_set))
        info["output_modalities"] = sorted(list(out_set))
        if info["modalities"]:
            info["supports_vision"] = "image" in info["modalities"] or "video" in info["modalities"]
        if max_input_tokens is not None:
            info["max_input_tokens"] = max_input_tokens
        if max_output_tokens is not None:
            info["max_output_tokens"] = max_output_tokens
        if max_tokens is not None:
            info["max_tokens"] = max_tokens

        info = merge_dicts(info, pricing)
        info = merge_dicts(info, model)
    except Exception as e:
        print(f"Model info error for {model.get('id')}: {e}")
        info = {}

    return info
