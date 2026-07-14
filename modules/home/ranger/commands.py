import os
import subprocess
import tempfile
import re
from ranger.api.commands import Command

class mount_archive(Command):
    """
    :mount_archive

    Mount the selected archive using archivemount to a directory under /tmp
    and navigate into it.
    """
    def execute(self):
        thisfile = self.fm.thisfile
        if not thisfile.is_file:
            self.fm.notify("Not a file", bad=True)
            return

        # Create a temp directory for the mountpoint
        safe_name = re.sub(r'[^a-zA-Z0-9_.-]', '_', thisfile.basename)
        mountpoint = tempfile.mkdtemp(prefix=f"ranger_mount_{safe_name}_")
        
        self.fm.notify(f"Mounting {thisfile.basename} to {mountpoint}...")
        try:
            res = subprocess.run(
                ["archivemount", thisfile.path, mountpoint],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            if res.returncode == 0:
                self.fm.cd(mountpoint)
                self.fm.notify("Successfully mounted archive!")
            else:
                self.fm.notify(f"archivemount failed: {res.stderr.strip()}", bad=True)
                try:
                    os.rmdir(mountpoint)
                except:
                    pass
        except Exception as e:
            self.fm.notify(f"Error mounting archive: {e}", bad=True)
            if os.path.exists(mountpoint):
                try:
                    os.rmdir(mountpoint)
                except:
                    pass

class unmount_archive(Command):
    """
    :unmount_archive

    Unmount the current directory if it is an archive mount point under /tmp/ranger_mount_*.
    """
    def execute(self):
        cwd = self.fm.thisdir.path
        if "/ranger_mount_" in cwd:
            parts = cwd.split('/')
            mount_idx = -1
            for i, part in enumerate(parts):
                if part.startswith("ranger_mount_"):
                    mount_idx = i
                    break
            
            if mount_idx == -1:
                self.fm.notify("Not inside an archive mountpoint", bad=True)
                return
                
            mountpoint = "/".join(parts[:mount_idx+1])
            self.fm.notify(f"Unmounting {mountpoint}...")
            
            try:
                # cd back to the parent of the mountpoint
                parent_dir = os.path.dirname(mountpoint)
                self.fm.cd(parent_dir)
                
                res = subprocess.run(
                    ["fusermount", "-u", mountpoint],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                if res.returncode == 0:
                    self.fm.notify("Successfully unmounted archive.")
                    try:
                        os.rmdir(mountpoint)
                    except Exception as rmdir_err:
                        self.fm.notify(f"Could not remove empty directory: {rmdir_err}")
                else:
                    self.fm.notify(f"fusermount failed: {res.stderr.strip()}", bad=True)
                    # cd back if failed
                    self.fm.cd(cwd)
            except Exception as e:
                self.fm.notify(f"Error unmounting: {e}", bad=True)
                self.fm.cd(cwd)
        else:
            self.fm.notify("Not inside an archive mountpoint", bad=True)

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
