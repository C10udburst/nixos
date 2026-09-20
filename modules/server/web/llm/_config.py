#!/usr/bin/env python3
import os
import sys
import yaml
import requests

secret_path = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LITELLM_SECRET_PATH", "/run/agenix/litellm")
output_path = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("LITELLM_CONFIG_PATH", "config.yaml")

if os.path.exists(secret_path):
    try:
        with open(secret_path, "r", encoding="utf-8") as f:
            exec(f.read(), globals())
        print(f"Loaded secret from {secret_path}")
    except Exception as e:
        print(f"Warning: Failed to load secret from {secret_path}: {e}")
else:
    print(f"Notice: Secret file {secret_path} does not exist. Using defaults.")

OAPI_COMPAT = globals().get("OAPI_COMPAT", {})
OLLAMA_URLS = globals().get("OLLAMA_URLS", {})
GITHUB_KEYS = globals().get("GITHUB_KEYS", [])
AZURE_DATA = globals().get("AZURE_DATA", [])
G4F_URL = globals().get("G4F_URL", None)
OPENROUTER_KEYS = globals().get("OPENROUTER_KEYS", [])
GOOGLE_KEYS = globals().get("GOOGLE_KEYS", [])
OPENAI_KEYS = globals().get("OPENAI_KEYS", [])
HUGGINGFACE_KEYS = globals().get("HUGGINGFACE_KEYS", [])
GROQ_KEYS = globals().get("GROQ_KEYS", [])
PUBLIC_PROXIES = globals().get("PUBLIC_PROXIES", [])

models_list = []
model_pricing = {}

try:
    resp = requests.get(
        "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json",
        timeout=10,
    )
    if resp.ok:
        model_pricing = resp.json()
except Exception as e:
    print(f"Pricing fetch error: {e}")


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


def model_info(model):
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
        max_input_tokens = (
            get_anyof(
                model,
                [
                    "context_window_size",
                    "max_input_tokens",
                    "max_context_length",
                    "architecture.context_window_size",
                    "inputTokenLimit",
                ],
            )
            or get_anyof(pricing, ["context_window_size", "max_input_tokens", "max_context_length"])
            or 2048
        )
        max_output_tokens = (
            get_anyof(model, ["max_output_tokens", "architecture.max_output_tokens", "outputTokenLimit"])
            or get_anyof(pricing, ["max_output_tokens"])
            or 1024
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
        info["supports_vision"] = "image" in info["modalities"] or "video" in info["modalities"]
        info["max_input_tokens"] = max_input_tokens
        info["max_output_tokens"] = max_output_tokens

        info = merge_dicts(info, pricing)
        info = merge_dicts(info, model)
    except Exception as e:
        print(f"Model info error for {model.get('id')}: {e}")
        info = {}

    return info


if isinstance(OAPI_COMPAT, dict):
    for name, data in OAPI_COMPAT.items():
        try:
            url = data["url"]
            if not url.endswith("/"):
                url += "/"
            key = data.get("key")
            headers = {"Authorization": f"Bearer {key}"} if key else {}
            r = requests.get(f"{url}v1/models", headers=headers, timeout=10).json()
            for model in r.get("data", []):
                models_list.append({
                    "model_name": f"{name}/{model['id']}",
                    "litellm_params": {
                        "model": f"openai/{model['id']}",
                        "api_base": f"{url}v1/",
                        "api_key": key or "dummy",
                    },
                    "model_info": model_info(model),
                })
        except Exception as e:
            print(f"OAPI error ({name}): {e}")

if isinstance(OLLAMA_URLS, dict):
    for name, OLLAMA_URL in OLLAMA_URLS.items():
        try:
            ollama_base = OLLAMA_URL.rstrip("/")
            r = requests.get(f"{ollama_base}/v1/models", timeout=10).json()
            for model in r.get("data", []):
                try:
                    show = requests.post(f"{ollama_base}/api/show", json={"name": model["id"]}, timeout=10).json()
                except Exception:
                    show = {}
                model_data = show.get("details") or {}
                model_data["modalities"] = show.get("capabilities", [])
                model_data["supports_function_calling"] = "tools" in model_data["modalities"]
                model_data["supports_tool_choice"] = model_data["supports_function_calling"]
                model_data["supports_vision"] = "vision" in model_data["modalities"]
                model_data["supports_reasoning"] = (
                    "reasoning" in model_data["modalities"] or "thinking" in model_data["modalities"]
                )
                model_data["supports_audio_input"] = "audio" in model_data["modalities"]
                models_list.append({
                    "model_name": f"{name}/{model['id']}",
                    "litellm_params": {
                        "model": f"ollama/{model['id']}",
                        "api_base": f"{ollama_base}",
                    },
                    "model_info": model_data,
                })
        except Exception as e:
            print(f"Ollama error ({name}): {e}")

if GITHUB_KEYS:
    try:
        r = requests.get("https://models.github.ai/catalog/models", timeout=10).json()
        for model in r:
            if model.get("rate_limit_tier") not in ["low", "high", "embeddings"]:
                continue
            for api_key in GITHUB_KEYS:
                models_list.append({
                    "model_name": f"github/{model['id']}",
                    "litellm_params": {
                        "model": f"github/{model['id']}",
                        "api_key": api_key,
                        "api_base": "https://models.github.ai/inference",
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"GitHub error: {e}")

if AZURE_DATA:
    try:
        for azure_data in AZURE_DATA:
            r = requests.get(
                f"{azure_data['api_base']}/openai/v1/models",
                headers={"api-key": azure_data["api_key"]},
                timeout=10,
            ).json()
            for model in r.get("data", []):
                models_list.append({
                    "model_name": f"azure/{model['id']}",
                    "litellm_params": {
                        "model": f"azure/{model['id']}",
                        "api_base": azure_data["api_base"],
                        "api_key": azure_data["api_key"],
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"Azure error: {e}")

if G4F_URL:
    try:
        g4f_base = G4F_URL.rstrip("/")
        r = requests.get(f"{g4f_base}/v1/models", timeout=10).json()
        for model in r.get("data", []):
            if model.get("image") or model.get("provider"):
                continue
            models_list.append({
                "model_name": f"g4f/{model['id']}",
                "litellm_params": {
                    "model": f"openai/{model['id']}",
                    "api_base": f"{g4f_base}/v1/",
                    "api_key": "g4f-not-needed",
                },
                "model_info": model_info(model),
            })
    except Exception as e:
        print(f"G4F error: {e}")

if OPENROUTER_KEYS:
    try:
        r = requests.get("https://openrouter.ai/api/v1/models", timeout=10).json()
        for model in r.get("data", []):
            isFree = True
            pricing = model.get("pricing", {})
            for v in pricing.values():
                if str(v) != "0" and v != 0:
                    isFree = False
            if not isFree:
                continue
            for key in OPENROUTER_KEYS:
                models_list.append({
                    "model_name": f"openrouter/{model['id']}",
                    "litellm_params": {
                        "model": f"openrouter/{model['id']}",
                        "api_key": key,
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"OpenRouter error: {e}")

if GOOGLE_KEYS:
    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models?key={GOOGLE_KEYS[0]}"
        r = requests.get(url, timeout=10).json()
        for model in r.get("models", []):
            model_name = model["name"].split("/")[-1]
            for key in GOOGLE_KEYS:
                models_list.append({
                    "model_name": f"google/{model_name}",
                    "litellm_params": {
                        "model": f"gemini/{model_name}",
                        "api_key": key,
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"Google error: {e}")

if OPENAI_KEYS:
    try:
        r = requests.get(
            "https://api.openai.com/v1/models",
            headers={"Authorization": f"Bearer {OPENAI_KEYS[0]}"},
            timeout=10,
        ).json()
        for model in r.get("data", []):
            model_name = model["id"]
            for key in OPENAI_KEYS:
                models_list.append({
                    "model_name": f"openai/{model_name}",
                    "litellm_params": {
                        "model": f"openai/{model_name}",
                        "api_key": key,
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"OpenAI error: {e}")

if HUGGINGFACE_KEYS:
    try:
        r = requests.get(
            "https://router.huggingface.co/v1/models",
            headers={"Authorization": f"Bearer {HUGGINGFACE_KEYS[0]}"},
            timeout=10,
        ).json()
        for model in r.get("data", []):
            model_name = model["id"]
            for provider in model.get("providers", []):
                if provider.get("status") != "live":
                    continue
                pricing = provider.get("pricing", {})
                price = max(pricing.get("input", 0), pricing.get("output", 0))
                if price > 0.1:
                    continue
                provider_name = provider.get("provider")
                for key in HUGGINGFACE_KEYS:
                    models_list.append({
                        "model_name": f"huggingface/{model_name}",
                        "litellm_params": {
                            "model": f"huggingface/{provider_name}/{model_name}",
                            "api_key": key,
                        },
                        "model_info": model_info(model),
                    })
    except Exception as e:
        print(f"HuggingFace error: {e}")

if GROQ_KEYS:
    try:
        r = requests.get(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {GROQ_KEYS[0]}"},
            timeout=10,
        ).json()
        for model in r.get("data", []):
            model_name = model["id"]
            for key in GROQ_KEYS:
                models_list.append({
                    "model_name": f"groq/{model_name}",
                    "litellm_params": {
                        "model": f"groq/{model_name}",
                        "api_key": key,
                    },
                    "model_info": model_info(model),
                })
    except Exception as e:
        print(f"Groq error: {e}")

if PUBLIC_PROXIES:
    for instance in PUBLIC_PROXIES:
        try:
            inst_base = instance.rstrip("/")
            r = requests.get(f"{inst_base}/v1/models", timeout=10).json()
            for model in r.get("data", []):
                models_list.append({
                    "model_name": f"public/{model['id']}",
                    "litellm_params": {
                        "model": f"openai/{model['id']}",
                        "api_base": f"{inst_base}/v1/",
                        "api_key": "dummy",
                    },
                    "model_info": model_info(model),
                })
        except Exception as e:
            print(f"Public proxy error ({instance}): {e}")

grouping = {}
for model in models_list:
    base_model = model["model_name"].split("/")[-1]
    if ":" in base_model:
        base_model = base_model.split(":")[0]
    grouping.setdefault(base_model, [])
    grouping[base_model].append(model)

for base_model, group in grouping.items():
    model_ids = set(m["model_name"] for m in group)
    if len(model_ids) > 1:
        for model in group:
            new_model = model.copy()
            new_model["model_name"] = f"group/{base_model}"
            models_list.append(new_model)

config = {
    "model_list": models_list,
    "router_settings": {
        "routing_strategy": "usage-based-routing",
        "allowed_fails": 1,
    },
    "litellm_settings": {
        "drop_params": True,
    },
}

print("Total models:", len(models_list))
print("Per provider:")
providers = {}
for model in models_list:
    provider = model["model_name"].split("/")[0]
    providers.setdefault(provider, 0)
    providers[provider] += 1
for provider, count in providers.items():
    print(f"  {provider}: {count}")

if len(models_list) == 0 and os.path.exists(output_path) and os.path.getsize(output_path) > 0:
    print(f"Warning: 0 models fetched, preserving existing config at {output_path}")
else:
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    tmp_path = f"{output_path}.tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        yaml.dump(config, f, allow_unicode=True, default_flow_style=False)
    os.replace(tmp_path, output_path)
    print(f"Config successfully written to {output_path}")
