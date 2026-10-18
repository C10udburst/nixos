import requests
from modelinfo import model_info

name = "G4F"


def collect(models_list, s):
    G4F_URL = s.get("G4F_URL")
    if not G4F_URL:
        return

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
