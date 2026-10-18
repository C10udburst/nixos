import requests
from modelinfo import model_info

name = "OpenAI-compatible"


def collect(models_list, s):
    OAPI_COMPAT = s.get("OAPI_COMPAT", {})
    if not isinstance(OAPI_COMPAT, dict):
        return

    for name, data in OAPI_COMPAT.items():
        try:
            url = data["url"]
            if not url.endswith("/"):
                url += "/"
            key = data.get("key")
            headers = {"Authorization": f"Bearer {key}"} if key else {}
            r = requests.get(f"{url}v1/models", headers=headers, timeout=10).json()
            extra_base = {k: v for k, v in data.items() if k not in ("url", "key", "models")}
            model_overrides = data.get("models", {})
            for model in r.get("data", []):
                mid = model["id"]
                extra = extra_base.copy()
                if isinstance(model_overrides, dict) and mid in model_overrides:
                    extra.update(model_overrides[mid])
                models_list.append({
                    "model_name": f"{name}/{mid}",
                    "litellm_params": {
                        "model": f"openai/{mid}",
                        "api_base": f"{url}v1/",
                        "api_key": key or "dummy",
                    },
                    "model_info": model_info(model, extra=extra),
                })
        except Exception as e:
            print(f"OAPI error ({name}): {e}")
