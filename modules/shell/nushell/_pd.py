#!/usr/bin/env python3
"""
pd.py — run a pandas transformation on JSON-encoded tabular data from stdin.

Usage:
    echo '[{"a":1},{"a":2}]' | python3 pd.py 'df["b"] = df.a * 2' [col1 col2 ...]

Arguments:
    argv[1]   : Python expression / statement(s) to execute.
                `df` (a DataFrame) and `pd` (the pandas module) are pre-bound.
                Assign back to `df` or to `result` for the output value.
    argv[2:]  : Optional list of column names to select from the result DataFrame.

Output: JSON array of records written to stdout.
"""

import sys
import json
import pandas as pd


def main():
    if len(sys.argv) < 2:
        print("Usage: pd.py <script> [col1 col2 ...]", file=sys.stderr)
        sys.exit(1)

    user_script = sys.argv[1]
    columns = sys.argv[2:] if len(sys.argv) > 2 else []

    # --- Read input ---
    raw = sys.stdin.read()
    if not raw.strip():
        print("[]")
        return

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"JSON decode error: {e}", "type": "JSONDecodeError"}), file=sys.stderr)
        sys.exit(1)

    df = pd.DataFrame(data)

    # --- Execute user script ---
    # The user may mutate `df` in-place or assign a new value to `result`.
    local_vars = {"df": df, "pd": pd, "result": None}
    try:
        exec(user_script, {"pd": pd, "__builtins__": __builtins__}, local_vars)
    except Exception as e:
        print(
            json.dumps({"error": str(e), "type": type(e).__name__}),
            file=sys.stderr,
        )
        sys.exit(1)

    # Prefer an explicit `result` variable; fall back to the (possibly mutated) `df`.
    result = local_vars.get("result") or local_vars.get("df", df)

    # --- Serialize result ---
    try:
        if isinstance(result, pd.DataFrame):
            if columns:
                missing = [c for c in columns if c not in result.columns]
                if missing:
                    print(
                        json.dumps({"error": f"Columns not found: {missing}", "type": "KeyError"}),
                        file=sys.stderr,
                    )
                    sys.exit(1)
                result = result[columns]
            print(result.to_json(orient="records", date_format="iso"))

        elif isinstance(result, pd.Series):
            # Promote Series to a single-column DataFrame so output is always tabular.
            print(result.to_frame().to_json(orient="records", date_format="iso"))

        else:
            # Scalar, list, dict — serialise as-is.
            print(json.dumps(result, default=str))

    except Exception as e:
        print(
            json.dumps({"error": f"Serialisation error: {e}", "type": type(e).__name__}),
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
