import sys
import json
import os


def convert_to_sarif(input_data):
    # Initialize the base SARIF v2.1.0 structure
    sarif_log = {"$schema": "https://azurewebsites.net", "version": "2.1.0", "runs": []}

    # Extract findings from the root JSON object
    findings = input_data.get("evidence_findings", [])

    # Determine a default scanner name from the first finding if available
    default_scanner = "vulnxscan"
    if findings and len(findings) > 0:
        first_finding = findings[0]
        scanners = first_finding.get("scanners")
        if isinstance(scanners, list) and len(scanners) > 0:
            default_scanner = scanners[0]

    run = {"tool": {"driver": {"name": default_scanner, "rules": []}}, "results": []}

    rules_map = {}

    for finding in findings:
        vuln_id = finding.get("vuln_id", "UNKNOWN_VULN")
        package = finding.get("package", "unknown")
        version = finding.get("version", "unknown")
        url = finding.get("url", "")

        # 1. Parse and extract severity (handles strings, floats, ints, or empty values)
        severity_val = finding.get("severity")
        severity_score = None

        # Check if severity is a number or numeric string
        if severity_val is not None and severity_val != "":
            try:
                severity_score = float(severity_val)
            except ValueError:
                # Fallback if it is a text-based severity string
                severity_val = str(severity_val).strip().lower()

        # 2. Map severity to SARIF levels and calculate CVSS score for GitHub properties
        level = "warning"  # Default fallback level

        if severity_score is not None:
            # Standard CVSS v3/v4 numerical severity mapping
            if severity_score >= 9.0:
                level = "error"
            elif severity_score >= 7.0:
                level = "error"
            elif severity_score >= 4.0:
                level = "warning"
            else:
                level = "note"
        else:
            # Standard textual mapping if it wasn't a number
            if severity_val in ["high", "critical"]:
                level = "error"
            elif severity_val in ["medium", "low"]:
                level = "warning"
            elif severity_val in ["info", "negligible"]:
                level = "note"

        # 3. Register the vulnerability as a tool rule if not already present
        if vuln_id not in rules_map:
            rule = {
                "id": vuln_id,
                "shortDescription": {
                    "text": f"Vulnerability {vuln_id} detected in package {package}"
                },
                "helpUri": url,
            }

            # Attach security-severity property if a numerical CVSS score exists (Highly recommended for GitHub)
            if severity_score is not None:
                rule["properties"] = {"security-severity": f"{severity_score:.1f}"}
            run["tool"]["driver"]["rules"].append(rule)
            rules_map[vuln_id] = True

        # 4. Construct the SARIF result entry
        display_severity = (
            f"{severity_score:.1f}"
            if severity_score is not None
            else (severity_val if severity_val else "Not Specified")
        )

        result = {
            "ruleId": vuln_id,
            "level": level,
            "message": {
                "text": f"Package '{package}' (version {version}) is vulnerable to {vuln_id}. Severity: {display_severity}. Target: {finding.get('target', 'N/A')}"
            },
            "locations": [
                {
                    "physicalLocation": {
                        "artifactLocation": {
                            "uri": finding.get("target", "unknown_target")
                        }
                    }
                }
            ],
            "properties": {
                "findingId": finding.get("finding_id"),
                "patchState": finding.get("patch_state"),
                "flakeref": finding.get("flakeref"),
                "rawSeverity": finding.get("severity"),  # Retain the exact source data
            },
        }
        run["results"].append(result)

    sarif_log["runs"].append(run)
    return sarif_log


def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py <path_to_input_file.json>")
        sys.exit(1)

    input_file_path = sys.argv[1]

    if not os.path.exists(input_file_path):
        print(f"Error: File '{input_file_path}' does not exist.")
        sys.exit(1)

    try:
        with open(input_file_path, "r", encoding="utf-8") as f:
            input_data = json.load(f)

        sarif_data = convert_to_sarif(input_data)

        base_name, _ = os.path.splitext(input_file_path)
        output_file_path = f"{base_name}.sarif"

        with open(output_file_path, "w", encoding="utf-8") as f:
            json.dump(sarif_data, f, indent=2)

        print(f"Success: Converted data saved to '{output_file_path}'")

    except json.JSONDecodeError:
        print("Error: Input file is not a valid JSON document.")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
