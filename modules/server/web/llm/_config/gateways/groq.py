import requests
from modelinfo import model_info

name = "Groq"


def collect(models_list, s):
    GROQ_KEYS = s.get("GROQ_KEYS", [])
    if not GROQ_KEYS:
        return

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
