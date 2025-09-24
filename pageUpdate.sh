#!/usr/bin/env bash
# Published under the MIT license

set -euo pipefail

# Default configuration
RECURSIVE=0
DRY_RUN=0
BACKUP_BASE=""
EXCLUDE_FILE="excludedFiles.txt"
EXCLUDE_DIR_FILE="excludedDirectories.txt"
BOILERPLATE="./boilerplate.html"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [working_directory]

Options:
  -r, --recursive         Recurse into subdirectories and update all .html files
  -b DIR, --backup DIR    Save backups under DIR (default: ./pageUpdate_backups/<timestamp>)
  -n, --dry-run           Show what would be changed without writing files
  -y, --yes               Assume yes for interactive prompts (skip confirmation)
  -h, --help              Show this help message

If working_directory is omitted the script will prompt for it.

The exclude file (by default '$EXCLUDE_FILE') supports one pattern per line, comments starting with
'#', and shell-style globs. Patterns containing '/' are matched against the file's relative path;
otherwise they match the basename.

Examples:
  Preview changes without modifying files
    $(basename "$0") -n /path/to/site

  Update site recursively and store backups in /tmp/backups
    $(basename "$0") -r -b /tmp/backups /path/to/site

  Non-interactive run (use carefully)
    $(basename "$0") -r -b /tmp/backups -y /path/to/site

EOF
}

# Capture original invocation (for logging) and parse args
ORIGINAL_INVOCATION="$0 $*"
ASSUME_YES=0
while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -r|--recursive) RECURSIVE=1; shift ;;
    -b|--backup) BACKUP_BASE="$2"; shift 2 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "${WORKING_DIRECTORY:-}" ]]; then
        WORKING_DIRECTORY="$1"
        shift
      else
        echo "Unexpected argument: $1"; usage; exit 1
      fi
      ;;
  esac
done

# Ask for working directory if not provided
if [[ -z "${WORKING_DIRECTORY:-}" ]]; then
  read -r -p "Enter the directory you would like to use as a complete or relative path: " WORKING_DIRECTORY
fi

if [[ -z "$WORKING_DIRECTORY" ]]; then
  echo "No working directory provided. Exiting." >&2
  exit 1
fi

cd "$WORKING_DIRECTORY" || { echo "Directory is not valid: $WORKING_DIRECTORY" >&2; exit 1; }
echo "Working directory is $PWD"

# Prepare log file in working directory (overwrite on each run)
LOGFILE="$PWD/tmp/pageUpdate.log"
mkdir "$PWD/tmp" 2>/dev/null || true
rm -f "$LOGFILE" 2>/dev/null || true
timestamp=$(date --rfc-3339=seconds 2>/dev/null || date)
printf "pageUpdate log - %s\n\n" "$timestamp" > "$LOGFILE"

# logging helper: echoes to stdout and appends to logfile
log() {
  printf '%s\n' "$*" | tee -a "$LOGFILE"
}

# Log invocation and flags
log "Invocation: $ORIGINAL_INVOCATION"
log "Flags: RECURSIVE=$RECURSIVE DRY_RUN=$DRY_RUN BACKUP_BASE=$BACKUP_BASE ASSUME_YES=$ASSUME_YES"
log "Boilerplate: $BOILERPLATE"
log "Exclude file: $EXCLUDE_FILE"
log "Exclude dir file: $EXCLUDE_DIR_FILE"
log "Working directory: $PWD"

# Ensure boilerplate exists
if [[ ! -f "$BOILERPLATE" ]]; then
  echo "Error: $BOILERPLATE not found!" >&2
  exit 1
fi

# Build backup directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [[ -z "$BACKUP_BASE" ]]; then
  BACKUP_BASE="./pageUpdate_backups/$TIMESTAMP"
fi

if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "$BACKUP_BASE"
  echo "Backups will be written to: $BACKUP_BASE"
else
  echo "Dry-run mode: no backups or file writes will be performed. (Would use $BACKUP_BASE)"
fi

# Offer to remove previous backups in the same backup root (only when not dry-run and not auto-yes)
if [[ $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 ]]; then
  BACKUP_ROOT=$(dirname "$BACKUP_BASE")
  # collect candidates: everything inside BACKUP_ROOT except the current BACKUP_BASE
  candidates=()
  if [[ -d "$BACKUP_ROOT" ]]; then
    for p in "$BACKUP_ROOT"/*; do
      # skip if it doesn't exist (glob) or is the current backup dir
      [[ ! -e "$p" ]] && continue
      # Normalize paths for comparison
      if [[ "$(realpath -m "$p")" == "$(realpath -m "$BACKUP_BASE")" ]]; then
        continue
      fi
      candidates+=("$p")
    done
  fi

  if [[ ${#candidates[@]} -gt 0 ]]; then
    echo "Previous backup candidates found in $BACKUP_ROOT:"
    for c in "${candidates[@]}"; do echo "  $c"; done
    read -r -p "Remove these previous backups now? This will permanently delete them. [y/N]: " delresp
    case "$delresp" in
      [yY][eE][sS]|[yY])
        echo "Removing previous backups..."
        for c in "${candidates[@]}"; do
          if [[ -e "$c" ]]; then
            rm -rf -- "$c"
            echo "  removed $c"
          fi
        done
        ;;
      *) echo "Keeping previous backups." ;;
    esac
  fi
fi

# Load exclude patterns (support comments and globs)
EXCLUDE_PATTERNS=()
if [[ -f "$EXCLUDE_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim
    pattern=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # skip empty or comment
    if [[ -z "$pattern" || ${pattern:0:1} == '#' ]]; then
      continue
    fi
    EXCLUDE_PATTERNS+=("$pattern")
  done < "$EXCLUDE_FILE"
  EXCLUDE_PRESENT=1
else
  EXCLUDE_PRESENT=0
fi

# Offer to add the boilerplate file itself to excludedFiles.txt if it's not present
boiler_basename=$(basename "$BOILERPLATE")
# determine whether boiler_basename is already in EXCLUDE_PATTERNS
boiler_in_excludes=0
if [[ $EXCLUDE_PRESENT -eq 1 ]]; then
  if printf '%s\n' "${EXCLUDE_PATTERNS[@]:-}" | grep -Fxq "$boiler_basename" 2>/dev/null; then
    boiler_in_excludes=1
  fi
fi

if [[ $EXCLUDE_PRESENT -eq 0 || $boiler_in_excludes -eq 0 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Would add '$boiler_basename' to $EXCLUDE_FILE (dry-run) to avoid processing the boilerplate itself."
  else
    if [[ $ASSUME_YES -eq 1 ]]; then
      mkdir -p "$(dirname "$EXCLUDE_FILE")" 2>/dev/null || true
      touch "$EXCLUDE_FILE" 2>/dev/null || true
      echo "$boiler_basename" >> "$EXCLUDE_FILE"
      echo "Added '$boiler_basename' to $EXCLUDE_FILE to avoid processing the boilerplate itself."
      # reload patterns
      EXCLUDE_PATTERNS+=("$boiler_basename")
      EXCLUDE_PRESENT=1
    else
      read -r -p "Add '$boiler_basename' to $EXCLUDE_FILE to avoid processing the boilerplate itself? [Y/n]: " addbf
      case "$addbf" in
        [nN][oO]|[nN]) echo "Not adding '$boiler_basename' to $EXCLUDE_FILE." ;;
        *)
          mkdir -p "$(dirname "$EXCLUDE_FILE")" 2>/dev/null || true
          touch "$EXCLUDE_FILE" 2>/dev/null || true
          echo "$boiler_basename" >> "$EXCLUDE_FILE"
          echo "Added '$boiler_basename' to $EXCLUDE_FILE to avoid processing the boilerplate itself."
          EXCLUDE_PATTERNS+=("$boiler_basename")
          EXCLUDE_PRESENT=1
          ;;
      esac
    fi
  fi
fi

# Load excluded directories (one per line) from excludedDirectories.txt
EXCLUDE_DIR_PATTERNS=()
## If running recursively, offer to add backups folder to excludedDirectories.txt
if [[ $RECURSIVE -eq 1 ]]; then
  # Only operate on the file when not in dry-run
  already_present=0
  if [[ -f "$EXCLUDE_DIR_FILE" ]]; then
    # read file, ignore blank lines and comments, normalize entries (strip leading ./ and trailing /)
    while IFS= read -r line || [[ -n "$line" ]]; do
      line_trim=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [[ -z "$line_trim" ]] && continue
      [[ ${line_trim:0:1} == '#' ]] && continue
      norm=${line_trim#./}
      norm=${norm%/}
      if [[ "$norm" == "pageUpdate_backups" ]]; then
        already_present=1
        break
      fi
    done < "$EXCLUDE_DIR_FILE"
  fi

  if [[ $already_present -eq 0 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Would add 'pageUpdate_backups' to $EXCLUDE_DIR_FILE (dry-run)"
    else
      if [[ $ASSUME_YES -eq 1 ]]; then
        # create file if needed and append
        mkdir -p "$(dirname "$EXCLUDE_DIR_FILE")" 2>/dev/null || true
        touch "$EXCLUDE_DIR_FILE" 2>/dev/null || true
        echo "pageUpdate_backups" >> "$EXCLUDE_DIR_FILE"
        echo "Added 'pageUpdate_backups' to $EXCLUDE_DIR_FILE to avoid processing backups when running recursively."
      else
        read -r -p "Add 'pageUpdate_backups' to $EXCLUDE_DIR_FILE to avoid processing backups when running recursively? [Y/n]: " addresp
        case "$addresp" in
          [nN][oO]|[nN]) echo "Not adding 'pageUpdate_backups' to $EXCLUDE_DIR_FILE." ;;
          *)
            mkdir -p "$(dirname "$EXCLUDE_DIR_FILE")" 2>/dev/null || true
            touch "$EXCLUDE_DIR_FILE" 2>/dev/null || true
            echo "pageUpdate_backups" >> "$EXCLUDE_DIR_FILE"
            echo "Added 'pageUpdate_backups' to $EXCLUDE_DIR_FILE to avoid processing backups when running recursively."
            ;;
        esac
      fi
    fi
  fi
fi

if [[ -f "$EXCLUDE_DIR_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    dir=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [[ -z "$dir" || ${dir:0:1} == '#' ]]; then
      continue
    fi
    # normalize (strip leading ./ and trailing /)
    dir=${dir#./}
    dir=${dir%/}
    EXCLUDE_DIR_PATTERNS+=("$dir")
  done < "$EXCLUDE_DIR_FILE"
  EXCLUDE_DIR_PRESENT=1
else
  EXCLUDE_DIR_PRESENT=0
fi

# Helper: check if a given relative path is inside an excluded directory
should_exclude_dir() {
  local relpath="$1"
  # normalize
  relpath=${relpath#./}
  if [[ $EXCLUDE_DIR_PRESENT -eq 0 ]]; then
    return 1
  fi
  for d in "${EXCLUDE_DIR_PATTERNS[@]}"; do
    # exact match or prefix match
    if [[ "$relpath" == "$d" || "$relpath" == "$d"/* ]]; then
      return 0
    fi
  done
  return 1
}

# Extract head and nav from boilerplate (prefer GNU grep with -P and -z, fallback to awk)
# Probe whether grep supports -P and -z safely
if printf 'a' | grep -Pzo 'a' >/dev/null 2>&1; then
  head_content=$(grep -Pzo '(?s)(?<=<head>).*?(?=</head>)' "$BOILERPLATE" | tr -d '\0' || true)
  nav_content=$(grep -Pzo '(?s)(?<=<nav>).*?(?=</nav>)' "$BOILERPLATE" | tr -d '\0' || true)
else
  head_content=$(awk 'BEGIN{p=0} /<head>/{p=1; sub(/.*<head>/,""); if(match($0, /<\/head>/)){ sub(/<\/head>.*/,""); print; exit } if(length($0)) print; next} p{ if(match($0, /<\/head>/)){ sub(/<\/head>.*/,""); print; exit } print }' "$BOILERPLATE" || true)
  nav_content=$(awk 'BEGIN{p=0} /<nav>/{p=1; sub(/.*<nav>/,""); if(match($0, /<\/nav>/)){ sub(/<\/nav>.*/,""); print; exit } if(length($0)) print; next} p{ if(match($0, /<\/nav>/)){ sub(/<\/nav>.*/,""); print; exit } print }' "$BOILERPLATE" || true)
fi

# Flags indicating whether a section exists in the boilerplate
head_SET=0
NAV_SET=0
if [[ -n "$head_content" ]]; then head_SET=1; else echo "Warning: <head> not found in $BOILERPLATE"; fi
if [[ -n "$nav_content" ]]; then NAV_SET=1; else echo "Warning: <nav> not found in $BOILERPLATE"; fi

# Helper: check if a file path should be excluded
should_exclude() {
  local relpath="$1"
  local basename
  basename=$(basename "$relpath")
  if [[ $EXCLUDE_PRESENT -eq 0 ]]; then
    return 1
  fi
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$pat" == *"/"* ]]; then
      # pattern contains a slash -> match against relative path
      if [[ "$relpath" == "$pat" ]]; then
        return 0
      fi
    else
      # match against basename
      if [[ "$basename" == "$pat" ]]; then
        return 0
      fi
    fi
    # glob matching for patterns with wildcard chars
    if [[ "$relpath" == "$pat" || "$basename" == "$pat" ]]; then
      return 0
    fi
  done
  return 1
}

# Build list of files to process
FILES=()
if [[ $RECURSIVE -eq 1 ]]; then
  # Use find and read null-delimited to handle special characters
  while IFS= read -r -d $'\0' f; do
    FILES+=("$f")
  done < <(find . -type f -name '*.html' -print0)
else
  # Non-recursive: expand glob safely
  shopt -s nullglob
  for f in ./*.html; do
    FILES+=("$f")
  done
  shopt -u nullglob
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  log "No .html files found to process."; exit 0
fi

# Filter out files that live in excluded directories or match excluded file patterns
filtered=()
for f in "${FILES[@]}"; do
  rel=${f#./}
  # check directory exclusion first
  if should_exclude_dir "$rel"; then
    log "Skipping $rel (directory excluded)"
    continue
  fi
  # check file exclusion
  if should_exclude "$rel"; then
    log "Skipping $rel (file excluded)"
    continue
  fi
  filtered+=("$f")
done
FILES=("${filtered[@]}")

log "Discovered files to consider:"
for f in "${filtered[@]:-}"; do log "  $f"; done
log "Final files to process: ${#FILES[@]}"

# Confirm before making changes unless --yes was given
if [[ $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 ]]; then
  read -r -p "Proceed to backup and update ${#FILES[@]} files in '$PWD'? [y/N]: " resp
  case "$resp" in
    [yY][eE][sS]|[yY]) ;;
    *) log "Aborted by user."; exit 0 ;;
  esac
fi

for file in "${FILES[@]}"; do
  # normalize relpath (strip leading ./)
  relpath=${file#./}

  # skip boilerplate itself
  if [[ "$relpath" == "${BOILERPLATE#./}" || "$relpath" == "$BOILERPLATE" ]]; then
    continue
  fi

  # improved exclude matching
  if should_exclude "$relpath"; then
    log "Skipping $relpath (excluded)"
    continue
  fi

  # explicit guard: only process files that contain <head> or <nav>
  if ! grep -qiE '<head>|<nav>' "$file"; then
    log "Skipping $relpath (no <head> or <nav> found)"
    continue
  fi

  log "Processing $relpath..."

  # backup
  if [[ $DRY_RUN -eq 1 ]]; then
    log "  [dry-run] would backup and update: $relpath"
  else
    target_backup_dir="$BACKUP_BASE/$(dirname "$relpath")"
    mkdir -p "$target_backup_dir"
    cp -p -- "$file" "$target_backup_dir/$(basename "$relpath")"
    log "  backed up to $target_backup_dir/$(basename "$relpath")"
  fi

  # perform replacement using awk like before
  if [[ $DRY_RUN -eq 1 ]]; then
    log "  [dry-run] would replace <head> and <nav> in $relpath"
    continue
  fi

  tmpfile=$(mktemp)
  awk -v head="$head_content" -v NAV="$nav_content" -v head_SET="$head_SET" -v NAV_SET="$NAV_SET" '
    {
      if ($0 ~ /<head>/) {
        if (head_SET == "1") {
          print "<head>"
          print head
          # consume until </head>
          while (getline line) { if (line ~ /<\/head>/) break }
          print "</head>"
          next
        } else {
          # emit original head block unchanged
          print
          while (getline line) { print; if (line ~ /<\/head>/) break }
          next
        }
      }
      if ($0 ~ /<nav>/) {
        if (NAV_SET == "1") {
          print "<nav>"
          print NAV
          while (getline line) { if (line ~ /<\/nav>/) break }
          print "</nav>"
          next
        } else {
          print
          while (getline line) { print; if (line ~ /<\/nav>/) break }
          next
        }
      }
      print
    }' "$file" > "$tmpfile" && mv "$tmpfile" "$file"

  log "  updated $relpath"
done
log "All done."