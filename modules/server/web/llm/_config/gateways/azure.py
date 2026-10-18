import requests
from modelinfo import model_info

name = "Azure"


def collect(models_list, s):
    AZURE_DATA = s.get("AZURE_DATA", [])
    if not AZURE_DATA:
        return

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
