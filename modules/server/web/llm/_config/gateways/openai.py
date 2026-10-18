import requests
from modelinfo import model_info

name = "OpenAI"


def collect(models_list, s):
    OPENAI_KEYS = s.get("OPENAI_KEYS", [])
    if not OPENAI_KEYS:
        return

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
