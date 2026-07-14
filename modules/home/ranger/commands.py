import os
from ranger.api.commands import Command

class binwalk_extract(Command):
    """
    :binwalk_extract

    Run binwalk -e on the selected file to extract files from it.
    """
    def execute(self):
        thisfile = self.fm.thisfile
        if not thisfile.is_file:
            self.fm.notify("Not a file", bad=True)
            return

        self.fm.notify(f"Extracting {thisfile.basename} with binwalk...")
        self.fm.run(f"binwalk -e '{thisfile.path}'", flags="f")
