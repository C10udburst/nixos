import re
import sys


def parse_gcode_bounds(file_path):
    # Regex patterns for finding XYZ coordinates
    x_pattern = re.compile(r"X\s*([+-]?\d*\.\d+|[+-]?\d+)")
    y_pattern = re.compile(r"Y\s*([+-]?\d*\.\d+|[+-]?\d+)")
    z_pattern = re.compile(r"Z\s*([+-]?\d*\.\d+|[+-]?\d+)")

    # Initialize lists for found coordinates
    x_coords, y_coords, z_coords = [], [], []

    with open(file_path, "r") as file:
        for line in file:
            line = line.strip()
            # Ignore comments and empty lines
            if not line or line.startswith(";") or line.startswith("("):
                continue

            # Filter lines containing movement or coordinates
            if line.startswith(("G0", "G1", "G2", "G3", "X", "Y", "Z")):
                x_match = x_pattern.search(line)
                y_match = y_pattern.search(line)
                z_match = z_pattern.search(line)

                if x_match:
                    x_coords.append(float(x_match.group(1)))
                if y_match:
                    y_coords.append(float(y_match.group(1)))
                if z_match:
                    z_coords.append(float(z_match.group(1)))

    if not x_coords and not y_coords and not z_coords:
        print("Error: No XYZ coordinates found in the file.")
        return

    # Display results with fallback for missing axis data
    print(f"File: {file_path}")

    min_x = min(x_coords) if x_coords else "N/A"
    max_x = max(x_coords) if x_coords else "N/A"
    print(f"X Range: Min = {min_x}, Max = {max_x}")

    min_y = min(y_coords) if y_coords else "N/A"
    max_y = max(y_coords) if y_coords else "N/A"
    print(f"Y Range: Min = {min_y}, Max = {max_y}")

    min_z = min(z_coords) if z_coords else "N/A"
    max_z = max(z_coords) if z_coords else "N/A"
    print(f"Z Range: Min = {min_z}, Max = {max_z}")


if __name__ == "__main__":
    # Check if the user provided the file name argument
    if len(sys.argv) < 2:
        print("Usage: gcode-bounds <path_to_file.gcode>")
        sys.exit(1)

    # Get the file path from the first argument (sys.argv[1])
    gcode_file = sys.argv[1]

    try:
        parse_gcode_bounds(gcode_file)
    except FileNotFoundError:
        print(f"Error: File '{gcode_file}' not found. Check the path.")
        sys.exit(1)
