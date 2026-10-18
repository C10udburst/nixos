import requests
from modelinfo import model_info

name = "Public proxy"


def collect(models_list, s):
    PUBLIC_PROXIES = s.get("PUBLIC_PROXIES", [])
    if not PUBLIC_PROXIES:
        return

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
