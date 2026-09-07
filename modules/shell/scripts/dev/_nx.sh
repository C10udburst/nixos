#!/usr/bin/env bash
#
# A script to run an agentic tool with a prompt, then apply changes upon success.
set -eo pipefail

tool=""
prompt=""
args=()

# Parse optional flags
case "$1" in
    -pi)
        tool="pi"
        shift
        ;;
    -ag)
        tool="agy"
        shift
        ;;
    -cdx)
        tool="codex"
        shift
        ;;
    -cc)
        tool="claude"
        shift
        ;;
    -h|--help)
        echo "Usage: nx [FLAG] <prompt>"
        echo ""
        echo "Flags:"
        echo "  -pi   Use Pi (pi <prompt>)"
        echo "  -ag   Use Antigravity CLI (agy -i <prompt>) (default)"
        echo "  -cdx  Use Codex (codex <prompt>)"
        echo "  -cc   Use Claude Code (claude <prompt>)"
        echo "  -h    Show this help message"
        exit 0
        ;;
esac

# If no tool was set by flags, default to agy
if [ -z "$tool" ]; then
    tool="agy"
fi

prompt="$*"

if [ -z "$prompt" ]; then
    echo "Error: Prompt cannot be empty."
    echo "Usage: nx [FLAG] <prompt>"
    exit 1
fi

# Expand ~/nixos safely
NIXOS_DIR="$HOME/nixos"

if [ ! -d "$NIXOS_DIR" ]; then
    echo "Error: Directory $NIXOS_DIR does not exist."
    exit 1
fi

# Set up tool-specific arguments to pass the prompt inline and resume conversations
case "$tool" in
    agy)
        args=(-i "$prompt")
        resume_args=(--continue)
        ;;
    pi)
        args=("$prompt")
        resume_args=(--continue)
        ;;
    claude)
        args=("$prompt")
        resume_args=(--continue)
        ;;
    codex)
        args=("$prompt")
        resume_args=(resume --last)
        ;;
esac

pushd "$NIXOS_DIR" >/dev/null

echo "Starting $tool with prompt: $prompt"

# Run the agent tool. We temporarily disable set -e in case the agent exits with a non-zero code.
set +e
"$tool" "${args[@]}"
AGENT_EXIT_CODE=$?
set -e

if [ $AGENT_EXIT_CODE -ne 0 ]; then
    echo "Warning: Agent exited with non-zero status ($AGENT_EXIT_CODE)."
fi

echo "Agent execution completed. Running ./apply..."
if ./apply; then
    popd >/dev/null
    echo "Rebuild and apply succeeded."
else
    echo "Apply failed. Remaining in $NIXOS_DIR."
    # ask if the user wants to return to the agent tool for further edits
    read -p "Do you want to return to the agent tool for further edits? (y/n): " choice
    case "$choice" in
        y|Y )
            echo "Returning to $tool for further edits..."
            "$tool" "${resume_args[@]}"
            ;;
        * )
            echo "Exiting without further edits."
            ;;
    esac
fi
