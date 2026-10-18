import requests
from modelinfo import model_info

name = "Google"


def collect(models_list, s):
    GOOGLE_KEYS = s.get("GOOGLE_KEYS", [])
    if not GOOGLE_KEYS:
        return

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
