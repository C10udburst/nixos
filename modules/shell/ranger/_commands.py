"""Custom ranger commands of the dendritic configuration.

    :fzf [path]          full-screen fzf picker (directory -> cd, file -> point at it)
    :binwalk [file]      carve a file into /tmp/<name>.binwalk and enter it
    :rg <regex>          live filter of the directory by file contents, with ripgrep
    :gitignore [bool]    hide or show the git-ignored entries of the directory

The filters are pushed onto ranger's own ``filter_stack``, so they compose with
``:filter_stack``, ``:hidden`` and ``:narrow``.
"""

import os
import subprocess

import ranger.api.commands
from ranger.core.filter_stack import BaseFilter
from ranger.ext.get_executables import get_executables


def helper(argv, cwd=None, stdin_data=None):
    """Run a helper program without a shell, returning (code, stdout, stderr)."""
    try:
        result = subprocess.run(
            argv, cwd=cwd, input=stdin_data,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as error:
        return 127, b"", str(error).encode()
    return result.returncode, result.stdout, result.stderr


def set_filter(directory, key, filt):
    """Keep one of our filters per directory, identified by `key`."""
    previous = directory.__dict__.pop(key, None)
    if previous in directory.filter_stack:
        directory.filter_stack.remove(previous)
    if filt is not None:
        directory.filter_stack.append(filt)
        directory.__dict__[key] = filt


# ─────────────────────────────────────────────────────────────────────────────
#  :fzf
# ─────────────────────────────────────────────────────────────────────────────

class fzf(ranger.api.commands.Command):
    """
    :fzf [path]

    Full-screen fzf picker starting in the current (or given) directory.  fzf
    indexes the tree recursively on its own, so a chosen directory is entered
    and a chosen file is highlighted in its directory.  Mapped to <C-f>,
    replacing ranger's <PAGEDOWN> alias.
    """

    resolve_macros = False

    def execute(self):
        fm = self.fm
        if "fzf" not in get_executables():
            fm.notify("fzf: command not found", bad=True)
            return

        argument = self.rest(1).strip()
        root = os.path.abspath(os.path.expanduser(argument)) if argument else fm.thisdir.path

        # stdin stays on the terminal for fzf's own recursive walker; only the
        # printed selection is captured.
        process = fm.execute_command(
            ["fzf"], cwd=root, stdout=subprocess.PIPE, universal_newlines=True)
        selection = "" if process is None or process.stdout is None \
            else process.stdout.read().strip()
        if not selection:
            fm.notify("fzf: nothing selected")
            return

        target = os.path.abspath(os.path.join(root, selection))
        if os.path.isdir(target):
            fm.cd(target)
        elif os.path.lexists(target):
            fm.select_file(target)
        else:
            fm.notify("fzf: {name} vanished".format(name=selection), bad=True)


# ─────────────────────────────────────────────────────────────────────────────
#  :binwalk
# ─────────────────────────────────────────────────────────────────────────────

class binwalk(ranger.api.commands.Command):
    """
    :binwalk [file]

    Extract everything the selected file contains into /tmp/<name>.binwalk and
    enter it when binwalk is done.  An existing extraction directory is reused
    as it is, so binwalk is not run twice -- delete it to carve the file again.
    """

    def execute(self):
        fm = self.fm
        argument = self.rest(1).strip()
        source = os.path.abspath(os.path.expanduser(argument)) if argument else fm.thisfile.path
        if not source or not os.path.isfile(source):
            fm.notify("binwalk: no file selected", bad=True)
            return

        destination = os.path.join("/tmp", os.path.basename(source) + ".binwalk")
        if os.path.isdir(destination) and os.listdir(destination):
            fm.notify("binwalk: reusing {dest}".format(dest=destination))
        else:
            os.makedirs(destination, exist_ok=True)
            fm.notify("binwalk: extracting into {dest}".format(dest=destination))
            process = fm.run(
                ["binwalk", "--extract", "--matryoshka", "--directory", destination, source],
                cwd=os.path.dirname(source))
            if getattr(process, "returncode", 1):
                fm.notify("binwalk: exited with status {code}".format(
                    code=process.returncode), bad=True)

        if os.path.isdir(destination):
            fm.cd(destination)


# ─────────────────────────────────────────────────────────────────────────────
#  :rg -- live content filter
# ─────────────────────────────────────────────────────────────────────────────

def ripgrep_matches(pattern, path):
    """Top level entries of `path` holding a match, or None if rg refused.

    ripgrep does the walking: recursive, gitignore aware, smart case.  Only the
    first path component of every reported file matters, which is what the
    browser shows -- directories stay visible when they contain a match.
    """
    code, stdout, _stderr = helper(
        ["rg", "--files-with-matches", "--smart-case", "--regexp=" + pattern, "."], cwd=path)
    if code > 1:  # 0 = hits, 1 = no hits, anything above = broken pattern
        return None
    names = set()
    for line in stdout.split(b"\n"):
        if line:
            names.add(os.path.normpath(os.fsdecode(line)).split(os.sep, 1)[0])
    return names


class RipgrepFilter(BaseFilter):
    """Keep the entries ripgrep found contents in."""

    def __init__(self, pattern, names):
        self.pattern = pattern
        self.names = names

    def __call__(self, fobj):
        return fobj.basename in self.names

    def __str__(self):
        return "<Filter: rg contents ~ /{pat}/>".format(pat=self.pattern)


RG_KEY = "dendritic_rg_filter"
_rg_pattern = [None]   # live pattern, followed into every directory
_cd_hook = []          # keeps the bound signal handler alive


def apply_rg(fm, directory, pattern):
    """Filter `directory` down to the entries whose contents match `pattern`."""
    if not pattern:
        set_filter(directory, RG_KEY, None)
    else:
        names = ripgrep_matches(pattern, directory.path)
        if names is None:
            fm.notify("rg: invalid expression: {pat}".format(pat=pattern), bad=True)
            return False
        set_filter(directory, RG_KEY, RipgrepFilter(pattern, names))
    directory.refilter()
    return True


def install_cd_hook(fm):
    """Re-run the live ripgrep pattern whenever the directory changes."""
    if _cd_hook:
        return

    def on_cd(signal):
        directory = signal.new
        if directory is None:
            return
        applied = directory.__dict__.get(RG_KEY)
        if applied is None and not _rg_pattern[0]:
            return
        if applied is not None and applied.pattern == _rg_pattern[0] \
                and applied in directory.filter_stack:
            return  # this directory already runs the current pattern
        apply_rg(fm, directory, _rg_pattern[0])

    _cd_hook.append(fm.signal_bind("cd", on_cd))


class rg(ranger.api.commands.Command):
    """
    :rg <regex>

    Live filter of the directory by file contents: ripgrep runs on every
    keystroke, so the listing narrows down while typing, with ripgrep's own
    recursive, gitignore aware defaults and no fuzzy matching.  <Enter> keeps
    the pattern and it keeps filtering the directories you enter afterwards,
    <Esc> clears it everywhere.
    """

    resolve_macros = False

    def execute(self):
        fm = self.fm
        pattern = self.rest(1)
        install_cd_hook(fm)
        if apply_rg(fm, fm.thisdir, pattern):
            _rg_pattern[0] = pattern

        if self.quickly_executed:
            fm.open_console(self.line)

    def quick(self):
        """Run on every keystroke instead of only on <Enter>."""
        return True

    def cancel(self):
        _rg_pattern[0] = None
        set_filter(self.fm.thisdir, RG_KEY, None)
        self.fm.thisdir.refilter()


# ─────────────────────────────────────────────────────────────────────────────
#  :gitignore
# ─────────────────────────────────────────────────────────────────────────────

def git_ignored_names(path):
    """The names inside `path` that git ignores, or None if git refused."""
    try:
        names = sorted(os.listdir(path))
    except OSError:
        return set()
    if not names:
        return set()

    code, stdout, _stderr = helper(
        ["git", "check-ignore", "--stdin", "-z"], cwd=path,
        stdin_data=b"\0".join(os.fsencode(name) for name in names) + b"\0")
    if code > 1:  # 0 = something ignored, 1 = nothing ignored, above = no repository
        return None
    return {os.path.basename(os.fsdecode(chunk))
            for chunk in stdout.split(b"\0") if chunk}


class GitIgnoredFilter(BaseFilter):
    """Hide the entries git reports as ignored."""

    def __init__(self, ignored):
        self.ignored = ignored

    def __call__(self, fobj):
        return fobj.basename not in self.ignored

    def __str__(self):
        return "<Filter: not git-ignored ({count})>".format(count=len(self.ignored))


def gitignore_state(fm, path):
    """Per-directory visibility flag, kept in ranger's runtime metadata."""
    return bool(fm.metadata.metadata_cache.get(path, {}).get("gitignore_hidden", False))


def store_gitignore_state(fm, path, hidden):
    fm.metadata.metadata_cache.setdefault(path, {})["gitignore_hidden"] = bool(hidden)


GITIGNORE_KEY = "dendritic_gitignore_filter"


class gitignore(ranger.api.commands.Command):
    """
    :gitignore [true|false]

    Hide (`true`) or show (`false`) the git-ignored entries of the current
    directory, toggling when given no argument.  Every entry is checked in one
    batch with `git check-ignore --stdin` and the chosen state is remembered per
    directory in ranger's runtime metadata.
    """

    resolve_macros = False

    def execute(self):
        fm = self.fm
        path = fm.thisdir.path
        argument = self.arg(1).lower()

        if argument in ("", "none", "toggle"):
            hidden = not gitignore_state(fm, path)
        elif argument in ("true", "hide", "yes", "1"):
            hidden = True
        elif argument in ("false", "show", "no", "0"):
            hidden = False
        else:
            fm.notify("gitignore: expected true, false or no argument", bad=True)
            return

        if hidden:
            ignored = git_ignored_names(path)
            if ignored is None:
                fm.notify("gitignore: {path} is not inside a git work tree".format(path=path),
                          bad=True)
                return
            set_filter(fm.thisdir, GITIGNORE_KEY, GitIgnoredFilter(ignored))
        else:
            set_filter(fm.thisdir, GITIGNORE_KEY, None)

        fm.thisdir.refilter()
        store_gitignore_state(fm, path, hidden)
        fm.notify("gitignore: {state}".format(
            state="hiding ignored entries" if hidden else "showing ignored entries"))
