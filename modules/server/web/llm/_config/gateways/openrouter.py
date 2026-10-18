import requests
from modelinfo import model_info

name = "OpenRouter"


def collect(models_list, s):
    OPENROUTER_KEYS = s.get("OPENROUTER_KEYS", [])
    if not OPENROUTER_KEYS:
        return

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
