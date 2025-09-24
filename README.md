# Scripts

This project contains helper scripts used to manage a static site:

- `pageUpdate.sh` — synchronize `<header>` and `<nav>` sections from `boilerplate.html` into your site pages, with backups and optional recursion.
- `newPage.sh` — create a new HTML page from `boilerplate.html` and set the `<title>` (simple interactive helper).

Both scripts are POSIX/bash shell scripts and do not require perl. They use `grep`/`awk` for multi-line operations and support common GNU tools. Test them in a safe environment before using on production sites.

## pageUpdate.sh

Usage summary:

```bash
# Preview changes (no writes):
bash pageUpdate.sh -n /path/to/site

# Apply changes (non-recursive) and write backups to default timestamped folder:
bash pageUpdate.sh /path/to/site

# Recurse into subdirectories and use custom backup directory:
bash pageUpdate.sh -r -b /tmp/backups /path/to/site

# Skip interactive confirmations (dangerous):
bash pageUpdate.sh -r -b /tmp/backups -y /path/to/site
```

Options and behavior:

- `-r`, `--recursive`: recurse into subdirectories and update all `.html` files found.
- `-b DIR`, `--backup DIR`: write backups under DIR; by default backups are stored in `./pageUpdate_backups/<timestamp>/` inside the working directory.
- `-n`, `--dry-run`: show which files would be backed up and updated — no writes.
- `-y`, `--yes`: skip interactive confirmations (use with care).
- `-h`, `--help`: show script usage.

Exclusion file:
- The script reads `excludedFiles.txt` in the working directory (if present). The file accepts:
  - blank lines
  - comment lines starting with `#`
  - shell-style glob patterns (e.g. `*.stub.html`, `wiki/*`) — patterns with `/` are matched against the file's relative path; others match the basename.

Backups:
- Before updating a file, the script copies the original into the backup directory, preserving permissions.
- You will be prompted whether you want to remove previous backups located in the same backup root (unless `-y` is used).

Safety tips:
- Run with `-n` first and inspect the changes.
- Use `-b` with a custom folder outside of your web root, or add rules to `.htaccess` to deny access (the repository includes examples in the root README).

## newPage.sh

This script creates a new HTML file from `boilerplate.html` and sets the `<title>` tag. It's interactive and simple:

1. Run the script and provide the site directory when prompted.
2. Enter the new filename (e.g., `newpage.html`) and the page title when prompted.
3. The script copies `boilerplate.html` to the new filename and updates the `<title>`.

Notes and improvements:
- `newPage.sh` currently supports an optional custom stylesheet (interactive). It assumes `boilerplate.html` already contains a valid `<head>` section.
- If you want `newPage.sh` to automatically insert navigation or register the new page in an index, we can extend it.

## Example workflow

1. Create a new page:

```bash
bash newPage.sh
# follow prompts to create newpage.html
```

2. Update all pages with the latest boilerplate in dry-run mode, verify, then run for real:

```bash
bash pageUpdate.sh -n /path/to/site
bash pageUpdate.sh -r -b /path/to/backups /path/to/site
```

---

If you'd like, I can add automated tests, a `--prune` option to remove backups older than N days, or make `newPage.sh` non-interactive (flags for title and filename). Tell me which enhancement you'd like next.

## Example exclude files

Create `excludedFiles.txt` in your working directory to exclude specific files or patterns. Example contents:

```
# Ignore specific files
about.html
contactme.html

# Ignore all temporary stub pages
*.stub.html
```

Create `excludedDirectories.txt` to exclude entire directories (one per line). Example contents:

```
# Exclude generated backups and the HVAC working folder
pageUpdate_backups
HVAC

# Exclude a nested folder
wiki/tmp
```

Notes:
- Lines starting with `#` are ignored as comments.
- Directory entries are matched as prefixes against file relative paths (no globbing).

Automatic exclusion when recursing:
- When you run `pageUpdate.sh -r` the script will automatically add `pageUpdate_backups` to
  `excludedDirectories.txt` if it's not already present. This prevents the script from
  re-processing the generated backups directory when running recursively.

Logging
- The script automatically logs all user inputs, flags, and changed files to
 tmp/pageUpdate.log. The logfile will be overwritten on any subsequent executions.
 tmp will be automatically generated in the root directory. It is reccomended to add tmp to
the excludedDirectories.txt file as well as gitignore. 