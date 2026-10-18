import requests
from modelinfo import model_info

name = "HuggingFace"


def collect(models_list, s):
    HUGGINGFACE_KEYS = s.get("HUGGINGFACE_KEYS", [])
    if not HUGGINGFACE_KEYS:
        return

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
                        "model_info": model_info(model, provider),
                    })
    except Exception as e:
        print(f"HuggingFace error: {e}")
