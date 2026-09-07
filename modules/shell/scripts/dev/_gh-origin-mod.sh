#!/usr/bin/env bash
set -euo pipefail

# Ensure we are inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not inside a git repository." >&2
  exit 1
fi

REMOTE="origin"
# If "origin" doesn't exist, fall back to the first available remote
if ! git remote | grep -q "^${REMOTE}$"; then
  REMOTE=$(git remote | head -n 1)
  if [ -z "${REMOTE}" ]; then
    echo "Error: No git remotes found in this repository." >&2
    exit 1
  fi
fi

URL=$(git remote get-url "${REMOTE}")
echo "Current remote ${REMOTE} URL: ${URL}"

# Normalize URL by stripping trailing .git and trailing slashes
NORM_URL="${URL%.git}"
NORM_URL="${NORM_URL%/}"

# Determine current format and extract owner/repo
if [[ "${NORM_URL}" =~ ^https://github\.com/(.+)$ ]]; then
  PATH_PART="${BASH_REMATCH[1]}"
  CURRENT_FORMAT="https"
elif [[ "${NORM_URL}" =~ ^git@github\.com:(.+)$ ]]; then
  PATH_PART="${BASH_REMATCH[1]}"
  CURRENT_FORMAT="ssh"
elif [[ "${NORM_URL}" =~ ^ssh://git@github\.com/(.+)$ ]]; then
  PATH_PART="${BASH_REMATCH[1]}"
  CURRENT_FORMAT="ssh"
else
  echo "Error: Remote URL ${URL} is not a recognized GitHub HTTPS or SSH URL." >&2
  exit 1
fi

if [[ "${PATH_PART}" =~ ^([^/]+)/([^/]+)$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "Error: Failed to parse owner and repository from path part ${PATH_PART}." >&2
  exit 1
fi

# Parse target format from command line arguments
TARGET_FORMAT=""
if [ $# -gt 0 ]; then
  case "$1" in
    ssh)
      TARGET_FORMAT="ssh"
      ;;
    https)
      TARGET_FORMAT="https"
      ;;
    *)
      echo "Usage: $(basename "$0") [ssh|https]" >&2
      echo "Toggle or set the GitHub remote origin between SSH and HTTPS." >&2
      exit 1
      ;;
  esac
fi

if [ -z "${TARGET_FORMAT}" ]; then
  # Toggle format
  if [ "${CURRENT_FORMAT}" = "https" ]; then
    TARGET_FORMAT="ssh"
  else
    TARGET_FORMAT="https"
  fi
fi

if [ "${TARGET_FORMAT}" = "ssh" ]; then
  NEW_URL="git@github.com:${OWNER}/${REPO}.git"
else
  NEW_URL="https://github.com/${OWNER}/${REPO}.git"
fi

if [ "${URL}" = "${NEW_URL}" ]; then
  echo "Remote ${REMOTE} is already set to ${NEW_URL}"
else
  git remote set-url "${REMOTE}" "${NEW_URL}"
  echo "Successfully updated remote ${REMOTE} URL to: ${NEW_URL}"
fi
