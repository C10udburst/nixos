import json
import os
import re
import sys


def clean_and_normalize_uri(uri):
    """Strips noisy SARIF prefixes and normalizes backslashes to slashes."""
    cleaned = re.sub(r"^(?:\.\.\\ile://|file:///?|file://)", "", uri)
    return cleaned.replace("\\", "/")


def get_project_root(uris):
    """Finds the longest common directory prefix among a list of URIs."""
    if not uris:
        return ""

    # If there's only one file, the common prefix is just that file's directory
    if len(uris) == 1:
        idx = uris[0].rfind("/")
        return uris[0][: idx + 1] if idx != -1 else ""

    # Find the character-by-character common prefix
    prefix = os.path.commonprefix(uris)

    # Snap back to the last slash to ensure we don't cut mid-folder name
    # (e.g., stopping at "C:/projects/my_app" instead of "C:/projects/my_app_")
    idx = prefix.rfind("/")
    if idx != -1:
        return prefix[: idx + 1]
    return ""


def sarif_to_llm_md(input_file, output_file):
    try:
        with open(input_file, "r", encoding="utf-8") as f:
            sarif_data = json.load(f)
    except Exception as e:
        print(f"Error reading {input_file}: {e}")
        sys.exit(1)

    # --- PASS 1: Find the common project root ---
    all_uris = []
    for run in sarif_data.get("runs", []):
        for result in run.get("results", []):
            for loc in result.get("locations", []):
                uri = (
                    loc.get("physicalLocation", {})
                    .get("artifactLocation", {})
                    .get("uri")
                )
                if uri:
                    all_uris.append(clean_and_normalize_uri(uri))

    project_root = get_project_root(all_uris)
    if project_root:
        print(f"Detected project root: {project_root}")

    # --- PASS 2: Generate Token-Optimized Markdown ---
    md_output = []
    for run in sarif_data.get("runs", []):
        for result in run.get("results", []):
            rule_id = result.get("ruleId", "Unknown")
            message = result.get("message", {}).get("text", "No message")

            md_output.append(f"### {rule_id}: {message}")

            for loc in result.get("locations", []):
                phys_loc = loc.get("physicalLocation", {})

                raw_uri = phys_loc.get("artifactLocation", {}).get("uri", "")
                if raw_uri:
                    clean_path = clean_and_normalize_uri(raw_uri)
                    # Strip the heavy common prefix
                    if project_root and clean_path.startswith(project_root):
                        clean_path = clean_path[len(project_root):]
                else:
                    clean_path = "Unknown File"

                region = phys_loc.get("region", {})
                start_line = region.get("startLine", "?")
                end_line = region.get("endLine", "?")
                snippet = region.get("snippet", {}).get("text", "").strip()

                md_output.append(
                    f"`{clean_path}` (Lines {start_line}-{end_line})"
                )

                if snippet:
                    md_output.append("```kotlin\n" + snippet + "\n```")

            md_output.append("---")

    try:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_output))
        print(f"Successfully converted '{input_file}' to '{output_file}'")
    except Exception as e:
        print(f"Error writing to {output_file}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sarif-md <input.sarif.json> <output.md>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    sarif_to_llm_md(input_path, output_path)
