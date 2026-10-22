import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

# Instruction and separator matching prompt_format.json (jialinyyzz/humanizer)
INSTR = (
    "Rewrite the text below so it reads like a person wrote it, not a "
    "language model.\n\n"
    "Reorganize it as you see fit. Vary sentence length on purpose. "
    "Cut hedging,\n"
    "throat-clearing, and any sentence that only announces what comes next.\n"
    "Prefer the concrete word over the abstract one. It is fine to sound "
    "uneven.\n\n"
    "Every fact, number, unit, date, name and quotation must survive "
    "unchanged."
)
SEP = "\n\n### Rewritten:\n\n"
EXPECTED_FINGERPRINT = "cc51d66b4c593fbe"


def build_prompt(draft: str) -> str:
    """Build the exact humanizer prompt byte-for-byte."""
    return INSTR + "\n\n" + draft.strip() + SEP


def verify_fingerprint():
    test_prompt = build_prompt("X")
    fp = hashlib.sha256(test_prompt.encode("utf-8")).hexdigest()[:16]
    if fp != EXPECTED_FINGERPRINT:
        raise RuntimeError(
            f"Prompt fingerprint mismatch! Expected {EXPECTED_FINGERPRINT}, "
            f"got {fp}"
        )


def count_chinese_chars(text: str) -> int:
    """Count CJK ideographs in text."""
    return len(re.findall(r"[\u4e00-\u9fff]", text))


def resolve_endpoint(host_input: str) -> str:
    """
    Resolve target URL, ensuring it points to {hostname}:8080/v1/completions.
    """
    url = host_input.strip()
    if not url.startswith("http://") and not url.startswith("https://"):
        url = f"http://{url}"
    parsed = urllib.parse.urlsplit(url)
    hostname = parsed.hostname or "llm"
    port = parsed.port or 8080
    return f"{parsed.scheme}://{hostname}:{port}/v1/completions"


def request_completion(
    endpoint_url: str, prompt: str, max_tokens: int = 2048
) -> str:
    """
    Call OpenAI-compatible /v1/completions with humanizer sampling settings.
    """
    body = {
        "model": "humanizer",
        "prompt": prompt,
        "temperature": 1.0,
        "top_p": 0.95,
        "top_k": 0,
        "min_p": 0.0,
        "repeat_penalty": 1.0,
        "max_tokens": max_tokens,
    }

    req = urllib.request.Request(
        endpoint_url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(req, timeout=600) as resp:
        res = json.loads(resp.read().decode("utf-8"))

    if "choices" in res and len(res["choices"]) > 0:
        return res["choices"][0].get("text", "").strip()
    elif "error" in res:
        err = res["error"]
        raise RuntimeError(f"Remote error: {err}")
    else:
        raise RuntimeError(f"Unexpected response format: {res}")


def main():
    args = sys.argv[1:]
    llm_host = os.environ.get("LLM_HOST", "llm")
    input_file = None

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--help", "-h"):
            print(f"Usage: {sys.argv[0]} [OPTIONS] [FILE]")
            print("Rewrite AI text to read like human writing.\n")
            print("Reads draft from stdin or from FILE if provided.\n")
            print("Options:")
            print(
                "  --host, -H <host>    Remote LLM gateway host"
                " (default: $LLM_HOST or llm)"
            )
            print(
                "  --test               Run self-test on prompt fingerprint"
            )
            print("  --help, -h           Show this help message")
            sys.exit(0)
        elif arg == "--test":
            verify_fingerprint()
            print(
                f"Prompt fingerprint verified ({EXPECTED_FINGERPRINT})."
                " Self-test PASSED."
            )
            sys.exit(0)
        elif arg in ("--host", "-H") and i + 1 < len(args):
            llm_host = args[i + 1]
            i += 1
        elif not arg.startswith("-"):
            input_file = arg
        i += 1

    if input_file:
        with open(input_file, "r", encoding="utf-8") as f:
            draft = f.read()
    else:
        if sys.stdin.isatty():
            sys.stderr.write(
                "Reading draft from stdin (press Ctrl+D when finished)...\n"
            )
        draft = sys.stdin.read()

    if not draft or not draft.strip():
        sys.stderr.write("Error: Empty input draft received.\n")
        sys.exit(1)

    endpoint = resolve_endpoint(llm_host)
    prompt = build_prompt(draft)
    draft_is_chinese = count_chinese_chars(draft) > 5

    max_retries = 3
    for attempt in range(1, max_retries + 1):
        try:
            converted_text = request_completion(endpoint, prompt)
        except urllib.error.HTTPError as e:
            err_msg = e.read().decode("utf-8", errors="replace")
            sys.stderr.write(f"HTTP {e.code} from {endpoint}: {err_msg}\n")
            sys.exit(1)
        except Exception as e:
            sys.stderr.write(f"Error connecting to {endpoint}: {e}\n")
            sys.exit(1)

        # Resample if English draft returns unexpected Chinese characters
        if not draft_is_chinese and count_chinese_chars(converted_text) > 5:
            if attempt < max_retries:
                sys.stderr.write(
                    f"[humanizer] Warning: detected unintended Chinese "
                    f"characters in output, resampling"
                    f" ({attempt}/{max_retries})...\n"
                )
                continue

        sys.stdout.write(converted_text + "\n")
        sys.stdout.flush()
        return


if __name__ == "__main__":
    main()
