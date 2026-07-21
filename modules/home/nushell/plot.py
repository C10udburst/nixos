#!/usr/bin/env python3
import sys
import json
import base64
from io import BytesIO
from datetime import datetime
from collections import Counter
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def try_parse_datetime(val):
    """Attempt to parse a string value into a datetime object.

    Handles nanosecond precision timestamps emitted by Nushell by truncating
    the fractional-seconds part to at most 6 digits (Python's microsecond
    resolution).
    """
    if not isinstance(val, str):
        return None
    try:
        # Nushell emits timestamps like: 2026-07-21T16:43:42.837563518+02:00
        # Truncate fractional seconds to 6 digits so Python can parse them.
        if "." in val:
            prefix, suffix = val.split(".", 1)
            # Locate the start of the timezone offset (+, -, or Z)
            tz_index = -1
            for char in ["+", "-", "Z"]:
                idx = suffix.find(char)
                if idx != -1:
                    tz_index = idx
                    break

            if tz_index != -1:
                fraction = suffix[:tz_index][:6]
                tz = suffix[tz_index:]
                val = f"{prefix}.{fraction}{tz}"
            else:
                val = f"{prefix}.{suffix[:6]}"

        return datetime.fromisoformat(val.replace("Z", "+00:00"))
    except ValueError:
        return None


def serialize_kitty_graphics(image_bytes):
    """Send a PNG image to the terminal using the Kitty Graphics Protocol."""
    encoded = base64.b64encode(image_bytes).decode("ascii")
    chunk_size = 4096
    sys.stdout.write(f"\033_Ga=T,f=100,m=1;{encoded[:chunk_size]}\033\\")
    for i in range(chunk_size, len(encoded), chunk_size):
        chunk = encoded[i : i + chunk_size]
        m = 1 if i + chunk_size < len(encoded) else 0
        sys.stdout.write(f"\033_Gm={m};{chunk}\033\\")
    sys.stdout.write("\n")
    sys.stdout.flush()


def main():
    if len(sys.argv) < 2:
        print("Error: provide at least one column name.", file=sys.stderr)
        sys.exit(1)

    x_col = sys.argv[1]
    y_col = sys.argv[2] if len(sys.argv) > 2 else None

    # --- Read and parse JSON from stdin ---
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            print("Error: no input data received.", file=sys.stderr)
            sys.exit(1)
        data = json.loads(input_data)
    except Exception as e:
        print(f"JSON error: {e}", file=sys.stderr)
        sys.exit(1)

    if isinstance(data, dict):
        data = [data]
    elif not isinstance(data, list):
        sys.exit(1)

    # --- Extract column values ---
    try:
        x_vals = [row[x_col] for row in data if x_col in row]
        y_vals = [row[y_col] for row in data if y_col in row] if y_col else None
    except KeyError as e:
        print(f"Error: column {e} not found.", file=sys.stderr)
        sys.exit(1)

    if not x_vals:
        print("Error: no data to display.", file=sys.stderr)
        sys.exit(1)

    # --- Detect whether x values are datetime strings ---
    parsed_dates = [try_parse_datetime(v) for v in x_vals]
    x_is_date = all(d is not None for d in parsed_dates)

    if x_is_date:
        x_vals = parsed_dates  # Replace raw strings with datetime objects

    # --- Heuristic chart-type selection ---
    plot_type = "line"
    x_is_numeric = (
        all(isinstance(v, (int, float)) for v in x_vals) if not x_is_date else False
    )
    x_is_string = all(isinstance(v, str) for v in x_vals) if not x_is_date else False

    if y_vals:
        y_is_numeric = all(isinstance(v, (int, float)) for v in y_vals)
        if x_is_date:
            plot_type = "time_line"
        elif x_is_numeric and y_is_numeric:
            plot_type = "scatter"
        elif x_is_string and y_is_numeric:
            plot_type = "bar"
    else:
        if x_is_date:
            plot_type = "time_density"
        elif x_is_numeric:
            plot_type = "line"
        elif x_is_string:
            plot_type = "bar"

    # --- Render the chart ---
    plt.figure(figsize=(9, 4.5))

    if plot_type == "time_line":
        plt.plot(x_vals, y_vals, marker="o", linestyle="-", color="teal", alpha=0.8)
        plt.ylabel(y_col)
        plt.title(f"Time series: {y_col} over {x_col}")

    elif plot_type == "time_density":
        counts = Counter(x_vals)
        unique_dates = list(counts.keys())
        y_counts = [counts[d] for d in unique_dates]

        plt.scatter(
            unique_dates,
            y_counts,
            color="firebrick",
            alpha=0.6,
            s=100,
            edgecolor="black",
        )
        plt.ylabel("Event count / activity")
        plt.title(f"Timeline for: {x_col}")

    elif plot_type == "scatter":
        plt.scatter(x_vals, y_vals, alpha=0.6, color="purple")
        plt.xlabel(x_col)
        plt.ylabel(y_col)
        plt.title(f"Scatter plot: {x_col} vs {y_col}")

    elif plot_type == "bar":
        if len(x_vals) > 20:
            x_vals, y_vals = x_vals[:20], y_vals[:20] if y_vals else None
        if y_vals:
            plt.bar(x_vals, y_vals, color="skyblue", edgecolor="black")
            plt.ylabel(y_col)
        else:
            counts = Counter(x_vals)
            plt.bar(counts.keys(), counts.values(), color="skyblue", edgecolor="black")
        plt.xlabel(x_col)
        plt.xticks(rotation=45, ha="right")

    else:
        plt.plot(x_vals, y_vals if y_vals else x_vals, marker="o", color="orange")
        plt.title(f"Line chart for: {x_col}")

    # --- Auto-format date axis if applicable ---
    if x_is_date:
        ax = plt.gca()
        locator = mdates.AutoDateLocator()
        ax.xaxis.set_major_locator(locator)

        # Choose a label format based on the time span
        delta = max(x_vals) - min(x_vals)
        if delta.days < 1:
            fmt = "%H:%M:%S"
        elif delta.days < 30:
            fmt = "%m-%d %H:%M"
        elif delta.days < 365:
            fmt = "%Y-%m-%d"
        else:
            fmt = "%Y-%m"

        ax.xaxis.set_major_formatter(mdates.DateFormatter(fmt))
        plt.gcf().autofmt_xdate()

    plt.grid(True, linestyle="--", alpha=0.5)
    plt.tight_layout()

    buf = BytesIO()
    plt.savefig(buf, format="png", dpi=120)
    plt.close()
    buf.seek(0)

    serialize_kitty_graphics(buf.read())


if __name__ == "__main__":
    main()
