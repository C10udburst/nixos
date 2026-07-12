#!/usr/bin/env bash
set -euo pipefail

# Print help if requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "nix-py: Create an ephemeral Nix shell with python3 and specified packages."
  echo ""
  echo "Usage:"
  echo "  nix-py                       Scan for 'requirements.txt' in current directory"
  echo "  nix-py <file>                Read package names from the specified file"
  echo "  nix-py <pkg1>,<pkg2>,...     Create shell with comma-separated packages"
  echo "  nix-py <pkg1> <pkg2> ...     Create shell with space-separated packages"
  echo ""
  echo "Examples:"
  echo "  nix-py numpy,pandas,requests"
  echo "  nix-py requirements-dev.txt"
  echo "  nix-py scipy scikit-learn"
  exit 0
fi

packages=()

# Function to parse and add packages
add_package() {
  local raw_pkg="$1"
  local clean_pkg
  # Strip pep-508 version specifiers, extras, environment markers, and leading/trailing spaces
  clean_pkg=$(echo "$raw_pkg" | sed -E 's/[>=<!~@;].*//; s/\[.*\]//; s/^[[:space:]]+//; s/[[:space:]]+$//')
  if [ -n "$clean_pkg" ]; then
    packages+=("$clean_pkg")
  fi
}

# 1. No arguments: search for requirements.txt in current directory
if [ $# -eq 0 ]; then
  if [ -f "requirements.txt" ]; then
    echo "Found requirements.txt in current directory. Reading packages..."
    while IFS= read -r line || [ -n "$line" ]; do
      # Strip leading/trailing whitespace
      line=$(echo "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
      # Skip empty lines and comments
      if [[ -n "$line" && ! "$line" =~ ^# ]]; then
        add_package "$line"
      fi
    done < "requirements.txt"
  else
    echo "Usage: nix-py [requirements.txt | package1,package2,...]" >&2
    echo "Error: No requirements.txt found in the current directory, and no packages specified." >&2
    exit 1
  fi

# 2. One argument that is an existing file: read from that file
elif [ $# -eq 1 ] && [ -f "$1" ]; then
  echo "Reading packages from file: $1"
  while IFS= read -r line || [ -n "$line" ]; do
    # Strip leading/trailing whitespace
    line=$(echo "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    # Skip empty lines and comments
    if [[ -n "$line" && ! "$line" =~ ^# ]]; then
      add_package "$line"
    fi
  done < "$1"

# 3. Otherwise: treat arguments as package names (comma and/or space-separated)
else
  for arg in "$@"; do
    # Replace commas with spaces to split them
    IFS=',' read -ra split_args <<< "$arg"
    for part in "${split_args[@]}"; do
      # Trim whitespace
      part=$(echo "$part" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
      if [ -n "$part" ]; then
        add_package "$part"
      fi
    done
  done
fi

# De-duplicate packages
unique_packages=()
declare -A seen
for pkg in "${packages[@]}"; do
  if [ -z "${seen[$pkg]+_}" ]; then
    seen[$pkg]=1
    unique_packages+=("$pkg")
  fi
done

if [ ${#unique_packages[@]} -eq 0 ]; then
  echo "Error: No Python packages specified or found." >&2
  exit 1
fi

nix_packages_list=""
for pkg in "${unique_packages[@]}"; do
  escaped_pkg=$(echo "$pkg" | sed 's/"/\\"/g')
  nix_packages_list="$nix_packages_list \"$escaped_pkg\""
done

echo "Preparing Nix shell with python3 and packages: ${unique_packages[*]}"

# Construct the nix expression using single quotes to avoid escaping hell
# We resolve the Python package names dynamically at evaluation time
nix_expr='let
  pkgs = import <nixpkgs> {};
  pythonPkgs = pkgs.python3Packages;
  resolvePackage = name:
    let
      lowerName = pkgs.lib.toLower name;
      dashName = pkgs.lib.replaceStrings ["_"] ["-"] lowerName;
      underscoreName = pkgs.lib.replaceStrings ["-"] ["_"] lowerName;
      compactName = pkgs.lib.replaceStrings ["-" "_"] ["" ""] lowerName;
      namesToTry = [ name lowerName dashName underscoreName compactName ];
      foundName = pkgs.lib.findFirst (n: builtins.hasAttr n pythonPkgs) null namesToTry;
    in
      if foundName != null then
        pythonPkgs.${foundName}
      else
        throw "Python package '\''" + name + "'\'' is not found in python3Packages. Tried: " + pkgs.lib.concatStringsSep ", " namesToTry;
  packages = builtins.map resolvePackage [ '"$nix_packages_list"' ];
in
  pkgs.mkShell {
    buildInputs = [
      (pkgs.python3.withPackages (ps: packages))
    ];
  }
'

exec nix-shell -E "$nix_expr"
