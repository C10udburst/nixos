import sys


def merge_ics(output_name, input_files):
    with open(output_name, "w", encoding="utf-8") as outfile:
        # Calendar header
        outfile.write("BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Merged//EN\n")

        for file_path in input_files:
            try:
                with open(file_path, "r", encoding="utf-8") as infile:
                    is_event = False
                    for line in infile:
                        # Copy only VEVENT blocks
                        if line.startswith("BEGIN:VEVENT"):
                            is_event = True
                        if is_event:
                            outfile.write(line)
                        if line.startswith("END:VEVENT"):
                            is_event = False
            except Exception as e:
                print(f"Error in file {file_path}: {e}")

        outfile.write("END:VCALENDAR\n")


if __name__ == "__main__":
    # Get all .ics files from command line arguments
    ics_files = [f for f in sys.argv[1:] if f.lower().endswith(".ics")]

    if not ics_files:
        print("Usage: ics-merge file1.ics file2.ics ...")
    else:
        merge_ics("merged.ics", ics_files)
        print(f"Done! Merged {len(ics_files)} files into 'merged.ics'")
