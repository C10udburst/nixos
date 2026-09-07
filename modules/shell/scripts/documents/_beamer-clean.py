import sys
from pypdf import PdfReader, PdfWriter


def remove_beamer_overlays(input_path, output_path):
    try:
        reader = PdfReader(input_path)
        writer = PdfWriter()
        total_pages = len(reader.pages)

        print(f"[*] Analyzing {input_path} ({total_pages} total pages)...")

        # Beamer stores frame start indices in /PageLabels
        # We look for where the 'logical' page number changes
        try:
            page_labels = reader.trailer["/Root"]["/PageLabels"]["/Nums"]
            # These are pairs:
            # [index1, {label_info1}, index2, {label_info2}, ...]
            # We want the indices (0, 2, 4...) which are the
            # first page of each new frame
            frame_start_indices = page_labels[0::2]
        except KeyError:
            print(
                "[!] Error: This PDF doesn't contain standard "
                "Beamer page labels."
            )
            print("    It might not have been created with LaTeX Beamer.")
            return

        # The 'last' page of a frame is the page just before the
        # 'next' frame starts
        # We also must include the very last page of the document
        pages_to_keep = [
            i - 1 for i in frame_start_indices[1:]
        ] + [total_pages - 1]

        num_to_keep = len(pages_to_keep)
        print(f"[*] Found {num_to_keep} unique frames. Starting extraction...")

        for count, page_idx in enumerate(pages_to_keep, 1):
            writer.add_page(reader.pages[page_idx])

            # Display progress
            progress = (count / num_to_keep) * 100
            sys.stdout.write(
                f"\rProgress: [{count}/{num_to_keep}] "
                f"{progress:.1f}% complete"
            )
            sys.stdout.flush()

        with open(output_path, "wb") as f:
            writer.write(f)

        print(f"\n[+] Success! Cleaned PDF saved to: {output_path}")

    except Exception as e:
        print(f"\n[!] An error occurred: {e}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: beamer-clean <input.pdf> <output.pdf>")
    else:
        remove_beamer_overlays(sys.argv[1], sys.argv[2])
