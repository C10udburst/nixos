import requests
from modelinfo import model_info

name = "Ollama"


def collect(models_list, s):
    OLLAMA_URLS = s.get("OLLAMA_URLS", {})
    if not isinstance(OLLAMA_URLS, dict):
        return

    for name, OLLAMA_URL in OLLAMA_URLS.items():
        try:
            ollama_base = OLLAMA_URL.rstrip("/")
            r = requests.get(f"{ollama_base}/v1/models", timeout=10).json()
            for model in r.get("data", []):
                try:
                    show = requests.post(f"{ollama_base}/api/show", json={"name": model["id"]}, timeout=10).json()
                except Exception:
                    show = {}

                extra = {}
                details = show.get("details") or {}
                extra.update(details)

                # Extract context length from GGUF model_info or parameters
                show_model_info = show.get("model_info") or {}
                for k, v in show_model_info.items():
                    if k.endswith(".context_length"):
                        extra["context_length"] = v
                        break
                if "context_length" not in extra:
                    params = show.get("parameters", "")
                    for line in params.splitlines():
                        parts = line.strip().split()
                        if len(parts) == 2 and parts[0] == "num_ctx":
                            extra["num_ctx"] = parts[1]
                            break

                caps = show.get("capabilities", [])
                if caps:
                    extra["modalities"] = caps
                    extra["supports_function_calling"] = "tools" in caps
                    extra["supports_tool_choice"] = "tools" in caps
                    extra["supports_vision"] = "vision" in caps
                    extra["supports_reasoning"] = "reasoning" in caps or "thinking" in caps
                    extra["supports_audio_input"] = "audio" in caps

                info = model_info(model, extra)
                for k in [
                    "supports_function_calling",
                    "supports_tool_choice",
                    "supports_vision",
                    "supports_reasoning",
                    "supports_audio_input",
                ]:
                    if k in extra:
                        info[k] = extra[k]

                models_list.append({
                    "model_name": f"{name}/{model['id']}",
                    "litellm_params": {
                        "model": f"ollama/{model['id']}",
                        "api_base": f"{ollama_base}",
                    },
                    "model_info": info,
                })
        except Exception as e:
            print(f"Ollama error ({name}): {e}")
