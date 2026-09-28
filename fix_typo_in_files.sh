#!/bin/bash
# ============================================================
# Fix "rapsberry" → "raspberry" across the repo
# ============================================================
# Bash 3.2 compatible (works on macOS default bash)
# ============================================================

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${MAGENTA}[SUCCESS]${NC} $1"; }

# ============= PARSE ARGS =============
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --help|-h)
            echo "Usage: bash fix_rapsberry_typo.sh [--dry-run]"
            exit 0
            ;;
    esac
done

# ============= SANITY CHECKS =============
if [ ! -d ".git" ]; then
    error "Not inside a git repo. cd to the repo root first."
fi

if ! command -v git &> /dev/null; then
    error "git is not installed."
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
info "Repo root: $REPO_ROOT"

if [ "$DRY_RUN" = "1" ]; then
    warn "DRY RUN MODE — nothing will be changed"
fi

# ============= STEP 1: RENAME FILES & DIRECTORIES =============
log "🔍 Finding files/dirs with 'rapsberry' in their name..."

# Build a temp file with the list of paths to rename (deepest first)
TMP_RENAME_LIST="$(mktemp)"
find . -depth \( -iname '*rapsberry*' \) \
    -not -path './.git/*' \
    2>/dev/null | sort -r > "$TMP_RENAME_LIST"

RENAME_COUNT=$(wc -l < "$TMP_RENAME_LIST" | tr -d ' ')

if [ "$RENAME_COUNT" = "0" ]; then
    log "✅ No files or directories named 'rapsberry' — skipping rename step."
    rm -f "$TMP_RENAME_LIST"
else
    info "Found $RENAME_COUNT path(s) to rename:"
    while IFS= read -r p; do
        newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
        if [ "$p" != "$newpath" ]; then
            echo "   $p  →  $newpath"
        fi
    done < "$TMP_RENAME_LIST"
    echo ""

    if [ "$DRY_RUN" != "1" ]; then
        # Read again (need to re-read the list since while-loop consumed it)
        while IFS= read -r p; do
            newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
            if [ "$p" != "$newpath" ]; then
                # Use git mv so history is preserved
                git mv "$p" "$newpath" 2>/dev/null || mv "$p" "$newpath"
                log "renamed: $p → $newpath"
            fi
        done < "$TMP_RENAME_LIST"
        success "✅ Files and directories renamed."
    else
        warn "Skipping rename (dry run)."
    fi

    rm -f "$TMP_RENAME_LIST"
fi

# ============= STEP 2: REWRITE FILE CONTENTS =============
log "🔍 Finding text files that mention 'rapsberry'..."

# Build a temp file with the list of text files
TMP_FILE_LIST="$(mktemp)"

# Extensions we care about (skip binaries)
find . -type f \( \
    -iname "*.sh" -o -iname "*.bash" -o -iname "*.py" -o \
    -iname "*.md" -o -iname "*.txt" -o -iname "*.json" -o \
    -iname "*.html" -o -iname "*.htm" -o -iname "*.css" -o \
    -iname "*.js" -o -iname "*.yml" -o -iname "*.yaml" -o \
    -iname "*.ini" -o -iname "*.conf" -o -iname "*.cfg" -o \
    -iname "*.toml" -o -iname "*.env" -o -iname "*.service" -o \
    -iname "*.sql" -o -iname "*.xml" -o -iname "*.csv" \
    \) -not -path './.git/*' 2>/dev/null > "$TMP_FILE_LIST"

TEXT_COUNT=$(wc -l < "$TMP_FILE_LIST" | tr -d ' ')

if [ "$TEXT_COUNT" = "0" ]; then
    warn "No text files with known extensions found. Nothing to rewrite."
else
    info "Scanning $TEXT_COUNT text file(s) for 'rapsberry'..."
fi

FILES_CHANGED=0

while IFS= read -r f; do
    if grep -qi 'rapsberry' "$f" 2>/dev/null; then
        HITS="$(grep -oi 'rapsberry' "$f" 2>/dev/null | wc -l | tr -d ' ')"
        info "  $f  ($HITS hit(s))"

        if [ "$DRY_RUN" != "1" ]; then
            # macOS sed needs '' after -i for in-place edit
            if sed --version >/dev/null 2>&1; then
                # GNU sed (Linux)
                sed -i \
                    -e 's/rapsberry/raspberry/g' \
                    -e 's/Rapsberry/Raspberry/g' \
                    -e 's/RAPSBERRY/RASPBERRY/g' \
                    "$f"
            else
                # BSD sed (macOS)
                sed -i '' \
                    -e 's/rapsberry/raspberry/g' \
                    -e 's/Rapsberry/Raspberry/g' \
                    -e 's/RAPSBERRY/RASPBERRY/g' \
                    "$f"
            fi
            FILES_CHANGED=$((FILES_CHANGED + 1))
        fi
    fi
done < "$TMP_FILE_LIST"

rm -f "$TMP_FILE_LIST"

if [ "$DRY_RUN" != "1" ]; then
    if [ "$FILES_CHANGED" -gt 0 ]; then
        success "✅ Rewrote $FILES_CHANGED text file(s)."
    else
        log "✅ No text file content needed rewriting."
    fi
else
    warn "Skipping content rewrite (dry run)."
fi

# ============= STEP 3: SUMMARY =============
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           RAPSBERRY → RASPBERRY FIX COMPLETE                   ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = "1" ]; then
    warn "DRY RUN — nothing was actually changed."
    info "Run without --dry-run to apply:"
    info "   bash fic.sh"
else
    success "✅ All changes applied."
    info ""
    info "🎯 Review before committing:"
    info "   git status"
    info "   git diff"
    info ""
    info "🎯 If something looks wrong, revert:"
    info "   git checkout -- ."
    info "   git reset HEAD ."
    info ""
    info "🎯 When happy, commit:"
    info "   git add -A"
    info "   git commit -m 'Fix rapsberry → raspberry typo across repo'"
    info "   git push"
fi

echo ""
info "⚠️  After renaming, any external URLs that referenced the old names"
info "    will break. Update them in:"
info "   - README.md"
info "   - Any HTML files with hardcoded raw.githubusercontent.com links"
info "   - Any docs on other sites (Wikis, Gists, etc.)"
echo ""

#!/bin/bash
# ============================================================
# Fix "rapsberry" → "raspberry" across the repo
# ============================================================
# Bash 3.2 compatible. Safe to re-run. Handles partial state.
# Sorts by PATH DEPTH (deepest first), not alphabetically.
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${MAGENTA}[SUCCESS]${NC} $1"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --help|-h) echo "Usage: bash fic.sh [--dry-run]"; exit 0 ;;
    esac
done

if [ ! -d ".git" ]; then
    error "Not inside a git repo. cd to the repo root first."
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
info "Repo root: $REPO_ROOT"
[ "$DRY_RUN" = "1" ] && warn "DRY RUN MODE — nothing will be changed"

# ============= STEP 1: RENAME FILES & DIRECTORIES =============
log "🔍 Finding files/dirs with 'rapsberry' in their name..."

# Build a list of paths with their DEPTH (number of slashes).
# Sort by depth descending (deepest first), then alphabetically.
TMP_RENAME_LIST="$(mktemp)"

find . -depth \( -iname '*rapsberry*' \) \
    -not -path './.git/*' \
    2>/dev/null \
    | while IFS= read -r p; do
        depth=$(echo "$p" | tr -cd '/' | wc -c | tr -d ' ')
        echo "$depth|$p"
    done \
    | sort -t'|' -k1,1nr -k2,2r \
    | cut -d'|' -f2- > "$TMP_RENAME_LIST"

RENAME_COUNT=$(wc -l < "$TMP_RENAME_LIST" | tr -d ' ')

if [ "$RENAME_COUNT" = "0" ]; then
    log "✅ No files or directories named 'rapsberry' — skipping rename step."
    rm -f "$TMP_RENAME_LIST"
else
    info "Found $RENAME_COUNT path(s) to rename (deepest first):"
    while IFS= read -r p; do
        newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
        [ "$p" != "$newpath" ] && echo "   $p  →  $newpath"
    done < "$TMP_RENAME_LIST"
    echo ""

    if [ "$DRY_RUN" != "1" ]; then
        while IFS= read -r p; do
            newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
            if [ "$p" != "$newpath" ]; then
                if [ ! -e "$p" ]; then
                    warn "skip (doesn't exist): $p"
                    continue
                fi
                if git mv "$p" "$newpath" 2>/dev/null; then
                    log "renamed (git): $p → $newpath"
                elif mv "$p" "$newpath" 2>/dev/null; then
                    log "renamed (mv):  $p → $newpath"
                else
                    warn "failed to rename: $p"
                fi
            fi
        done < "$TMP_RENAME_LIST"
        success "✅ Rename step complete."
    else
        warn "Skipping rename (dry run)."
    fi

    rm -f "$TMP_RENAME_LIST"
fi

# ============= STEP 2: REWRITE FILE CONTENTS =============
log "🔍 Finding text files that mention 'rapsberry'..."

TMP_FILE_LIST="$(mktemp)"

find . -type f \( \
    -iname "*.sh" -o -iname "*.bash" -o -iname "*.py" -o \
    -iname "*.md" -o -iname "*.txt" -o -iname "*.json" -o \
    -iname "*.html" -o -iname "*.htm" -o -iname "*.css" -o \
    -iname "*.js" -o -iname "*.yml" -o -iname "*.yaml" -o \
    -iname "*.ini" -o -iname "*.conf" -o -iname "*.cfg" -o \
    -iname "*.toml" -o -iname "*.env" -o -iname "*.service" -o \
    -iname "*.sql" -o -iname "*.xml" -o -iname "*.csv" \
    \) -not -path './.git/*' 2>/dev/null > "$TMP_FILE_LIST"

TEXT_COUNT=$(wc -l < "$TMP_FILE_LIST" | tr -d ' ')
info "Scanning $TEXT_COUNT text file(s) for 'rapsberry'..."

FILES_CHANGED=0

while IFS= read -r f; do
    [ ! -f "$f" ] && continue
    if grep -qi 'rapsberry' "$f" 2>/dev/null; then
        HITS="$(grep -oi 'rapsberry' "$f" 2>/dev/null | wc -l | tr -d ' ')"
        info "  $f  ($HITS hit(s))"

        if [ "$DRY_RUN" != "1" ]; then
            if sed --version >/dev/null 2>&1; then
                sed -i \
                    -e 's/rapsberry/raspberry/g' \
                    -e 's/Rapsberry/Raspberry/g' \
                    -e 's/RAPSBERRY/RASPBERRY/g' \
                    "$f"
            else
                sed -i '' \
                    -e 's/rapsberry/raspberry/g' \
                    -e 's/Rapsberry/Raspberry/g' \
                    -e 's/RAPSBERRY/RASPBERRY/g' \
                    "$f"
            fi
            FILES_CHANGED=$((FILES_CHANGED + 1))
        fi
    fi
done < "$TMP_FILE_LIST"

rm -f "$TMP_FILE_LIST"

if [ "$DRY_RUN" != "1" ]; then
    [ "$FILES_CHANGED" -gt 0 ] \
        && success "✅ Rewrote $FILES_CHANGED text file(s)." \
        || log "✅ No text file content needed rewriting."
else
    warn "Skipping content rewrite (dry run)."
fi

# ============= STEP 3: SUMMARY =============
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           RAPSBERRY → RASPBERRY FIX COMPLETE                   ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = "1" ]; then
    warn "DRY RUN — nothing changed."
    info "Run without --dry-run to apply:"
    info "   bash fic.sh"
else
    success "✅ All changes applied."
    echo ""
    info "🎯 Review before committing:"
    info "   git status"
    info "   git diff"
    echo ""
    info "🎯 If something looks wrong, revert:"
    info "   git checkout -- ."
    info "   git reset HEAD ."
    echo ""
    info "🎯 When happy, commit:"
    info "   git add -A"
    info "   git commit -m 'Fix rapsberry → raspberry typo across repo'"
    info "   git push"
fi
echo ""

#!/bin/bash
# Fix remaining rapsberry-* filenames inside raspberry-pi5-ssd/

set -e

cd "/Users/gabrielmay/Documents/igiteam/igi1-macbook-3d-workstation"

echo "🔍 Files still containing 'rapsberry' in name:"
find . -iname '*rapsberry*' -not -path './.git/*'

echo ""
echo "Renaming..."

# Rename each file, deepest first
find . -depth -iname '*rapsberry*' -not -path './.git/*' 2>/dev/null | while IFS= read -r p; do
    newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
    if [ "$p" != "$newpath" ]; then
        if git mv "$p" "$newpath" 2>/dev/null; then
            echo "  ✅ $p → $newpath"
        elif mv "$p" "$newpath" 2>/dev/null; then
            echo "  ✅ (mv) $p → $newpath"
        else
            echo "  ❌ FAILED: $p"
        fi
    fi
done

echo ""
echo "🔍 Remaining 'rapsberry' files (should be empty):"
find . -iname '*rapsberry*' -not -path './.git/*' || echo "  (none)"

echo ""
echo "✅ Done. Now run:"
echo "   git status"
echo "   git add -A"
echo "   git commit -m 'Fix rapsberry → raspberry typo'"
echo "   git push"