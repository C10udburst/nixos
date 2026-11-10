#!/usr/bin/env python3
import os
import subprocess
import sys

try:
    import tomli
except ImportError:
    print("Error: The 'tomli' package is required. Install it using: pip install tomli", file=sys.stderr)
    sys.exit(1)

# Unicode mapping dictionary for a cleaner layout
KEY_MAP = {
    # Modifiers
    "mod": "⌘",
    "super": "⌘",
    "win": "⌘",
    "shift": "⇧",
    "alt": "⎇",
    "ctrl": "⌃",
    "control": "⌃",
    # Special keys
    "enter": "⏎",
    "return": "⏎",
    "space": "␣",
    "backspace": "⌫",
    "tab": "⇥",
    "escape": "⎋",
    "esc": "⎋",
    # Punctuation & Math
    "period": ".",
    "comma": ",",
    "plus": "+",
    "minus": "-",
    "equal": "=",
    "equals": "=",
    "slash": "/",
    "backslash": "\\",
    "semicolon": ";",
    "apostrophe": "'",
    # Arrows
    "up": "↑",
    "down": "↓",
    "left": "←",
    "right": "→",
}


def clean_and_prettify(raw_keybind: str) -> str:
    """Removes XF86 prefixes, handles spacing, and replaces keys with Unicode glyphs."""
    # Remove XF86Audio, XF86Mon, etc., keeping only the core action name (e.g., RaiseVolume)
    if "xf86" in raw_keybind.lower():
        raw_keybind = raw_keybind.replace("XF86", "").replace("xf86", "")

    # Split by standard delimiters like '+' or '-' inside the config
    delimiter = "+" if "+" in raw_keybind else "-" if "-" in raw_keybind else " "
    parts = [p.strip() for p in raw_keybind.split(delimiter)]

    # Map parts to symbols if they exist, otherwise keep original title-cased text
    prettified_parts = []
    for part in parts:
        lower_part = part.lower()
        if lower_part in KEY_MAP:
            prettified_parts.append(KEY_MAP[lower_part])
        else:
            prettified_parts.append(part)

    # Join modifiers and keys cleanly with a slim space or no delimiter for symbols
    return " ".join(prettified_parts)


def main():
    config_path = os.path.expanduser("~/.config/driftwm/config.toml")

    if not os.path.exists(config_path):
        print(f"Error: Configuration file {config_path} not found.", file=sys.stderr)
        sys.exit(1)

    try:
        with open(config_path, "rb") as f:
            config = tomli.load(f)
    except Exception as e:
        print(f"Error parsing TOML file: {e}", file=sys.stderr)
        sys.exit(1)

    # Read the [keybindings] section
    keybindings = config.get("keybindings", {})
    if not keybindings:
        print("The [keybindings] section is missing or empty.", file=sys.stderr)
        sys.exit(0)

    # Create a mapping of the pretty menu string -> original action string
    menu_map = {}
    for raw_key, raw_action in keybindings.items():
        pretty_key = clean_and_prettify(raw_key)
        menu_entry = f"{pretty_key}  │  {raw_action.strip()}"
        menu_map[menu_entry] = raw_action.strip()

    # Compose input string for rofi (noctalia dmenu compat shim)
    rofi_input = "\n".join(menu_map.keys())

    # Spawn rofi dmenu
    try:
        rofi_proc = subprocess.run(
            ["rofi", "-dmenu", "-p", "⌨ Keybindings", "-i"],
            input=rofi_input,
            capture_output=True,
            text=True,
            check=True
        )
        selected = rofi_proc.stdout.strip()
    except subprocess.CalledProcessError:
        # Exit smoothly if the user presses Escape or closes the menu
        sys.exit(0)

    # Execute the command associated with the selection
    if selected in menu_map:
        action = menu_map[selected]
        cmd = ["driftwm", "msg", "action", action]
        try:
            subprocess.Popen(cmd)
        except Exception as e:
            print(f"Error executing command: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
