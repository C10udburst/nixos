"""One module per upstream gateway.

Each module exposes `name` (for error messages) and `collect(models_list, secrets)`,
which appends model_list entries and returns early when its own secrets are absent.
Order below is the order models are appended in, which decides which deployment a
`group/<model>` entry inherits -- keep it stable.
"""

from . import (
    azure,
    g4f,
    github,
    google,
    groq,
    huggingface,
    openai,
    openai_compat,
    ollama,
    openrouter,
    public_proxy,
)

GATEWAYS = [
    openai_compat,
    ollama,
    github,
    azure,
    g4f,
    openrouter,
    google,
    openai,
    huggingface,
    groq,
    public_proxy,
]
