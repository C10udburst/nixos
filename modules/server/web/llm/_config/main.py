#!/usr/bin/env python3
import os
import sys
import yaml

from gateways import GATEWAYS
from modelinfo import load_pricing

secret_path = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LITELLM_SECRET_PATH", "/run/agenix/litellm")
output_path = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("LITELLM_CONFIG_PATH", "config.yaml")

secrets = {}
if os.path.exists(secret_path):
    try:
        with open(secret_path, "r", encoding="utf-8") as f:
            exec(f.read(), secrets)
        print(f"Loaded secret from {secret_path}")
    except Exception as e:
        print(f"Warning: Failed to load secret from {secret_path}: {e}")
else:
    print(f"Notice: Secret file {secret_path} does not exist. Using defaults.")

models_list = []
load_pricing()

for gateway in GATEWAYS:
    try:
        gateway.collect(models_list, secrets)
    except Exception as e:
        print(f"{gateway.name} error: {e}")

grouping = {}
for model in models_list:
    base_model = model["model_name"].split("/")[-1]
    if ":" in base_model:
        base_model = base_model.split(":")[0]
    grouping.setdefault(base_model, [])
    grouping[base_model].append(model)

for base_model, group in grouping.items():
    model_ids = set(m["model_name"] for m in group)
    if len(model_ids) > 1:
        for model in group:
            new_model = model.copy()
            new_model["model_name"] = f"group/{base_model}"
            models_list.append(new_model)

config = {
    "model_list": models_list,
    "router_settings": {
        "routing_strategy": "usage-based-routing",
        "allowed_fails": 1,
    },
    "litellm_settings": {
        "drop_params": True,
    },
    "general_settings": {
        "allowed_cors_origins": ["*"],
    },
}

print("Total models:", len(models_list))
print("Per provider:")
providers = {}
for model in models_list:
    provider = model["model_name"].split("/")[0]
    providers.setdefault(provider, 0)
    providers[provider] += 1
for provider, count in providers.items():
    print(f"  {provider}: {count}")

if len(models_list) == 0 and os.path.exists(output_path) and os.path.getsize(output_path) > 0:
    print(f"Warning: 0 models fetched, preserving existing config at {output_path}")
else:
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    tmp_path = f"{output_path}.tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        yaml.dump(config, f, allow_unicode=True, default_flow_style=False)
    os.replace(tmp_path, output_path)
    print(f"Config successfully written to {output_path}")
