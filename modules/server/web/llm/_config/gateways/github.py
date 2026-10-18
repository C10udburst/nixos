import requests
from modelinfo import model_info

name = "GitHub"


def collect(models_list, s):
    GITHUB_KEYS = s.get("GITHUB_KEYS", [])
    if not GITHUB_KEYS:
        return

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
