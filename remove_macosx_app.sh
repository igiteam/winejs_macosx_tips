#!/bin/bash
#
# remove_macosx_app.sh
# Interactive macOS app uninstaller — removes app bundle + user/system leftovers.
#
# Usage:
#   ./remove_macosx_app.sh
#   (or) chmod +x remove_macosx_app.sh && ./remove_macosx_app.sh
#
# It will ask for an app name (e.g. "JDownloader", "Slack", "Visual Studio Code")
# and then search common locations for matching files, show them, and delete
# after confirmation.

set -u

# ---------- colours ----------
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[0;33m'
CYN=$'\033[0;36m'
BLD=$'\033[1m'
RST=$'\033[0m'

# ---------- helpers ----------
info()  { printf '%s[*]%s %s\n' "$CYN" "$RST" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$GRN" "$RST" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$YLW" "$RST" "$*"; }
err()   { printf '%s[x]%s %s\n' "$RED" "$RST" "$*" >&2; }

ask_yes_no() {
    local prompt="$1" reply
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ---------- banner ----------
clear
printf '%s' "$BLD"
cat <<'EOF'
=====================================================
        macOS Interactive App Uninstaller
=====================================================
EOF
printf '%s' "$RST"
echo

# ---------- input ----------
read -r -p "Enter the name of the app to remove (e.g. JDownloader): " APP_NAME
APP_NAME="${APP_NAME% }"          # trim trailing space
APP_NAME="${APP_NAME# }"          # trim leading space

if [[ -z "$APP_NAME" ]]; then
    err "No app name given. Aborting."
    exit 1
fi

# build a lowercase variant for case-insensitive matching
APP_LC="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]')"

# names to search for in bundle identifiers (strip spaces, lowercase)
BUNDLE_LC="$(printf '%s' "$APP_NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

printf '\n%sSearching for "%s" ...%s\n\n' "$BLD" "$APP_NAME" "$RST"

# ---------- locate matches ----------
# We collect candidate paths in an array.
MATCHES=()

add_if_exists() {
    local p="$1"
    [[ -e "$p" ]] && MATCHES+=("$p")
}

# 1) /Applications and ~/Applications
while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
    find /Applications "$HOME/Applications" -maxdepth 2 -iname "*${APP_NAME}*" -print0 2>/dev/null
)

# 2) User Library subfolders
LIB="$HOME/Library"
for sub in \
    "Application Support" \
    "Caches" \
    "Preferences" \
    "Logs" \
    "Saved Application State" \
    "LaunchAgents" \
    "Containers" \
    "Group Containers" \
    "WebKit" \
    "HTTPStorages" \
    "Cookies" \
    "Application Scripts"
do
    while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
        find "$LIB/$sub" -maxdepth 3 -iname "*${APP_NAME}*" -print0 2>/dev/null
    )
done

# 3) bundle-id style leftovers, e.g. com.install4j.jdownloader2.6232.plist
while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
    find "$LIB/Preferences" "$LIB/Saved Application State" "$LIB/Caches" \
         -maxdepth 2 -iname "*${BUNDLE_LC}*" -print0 2>/dev/null
)

# 4) System-wide locations (need sudo to delete, but we still show them)
for sub in "/Library/Application Support" "/Library/Caches" "/Library/Preferences" \
           "/Library/Logs" "/Library/LaunchAgents" "/Library/LaunchDaemons"; do
    while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
        find "$sub" -maxdepth 3 -iname "*${APP_NAME}*" -print0 2>/dev/null
    )
done

# 5) ~/.<app> style dotfiles/dirs
while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
    find "$HOME" -maxdepth 1 -iname ".${APP_LC}*" -print0 2>/dev/null
)

# 6) Downloads: installers / dmgs / pkgs
while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
    find "$HOME/Downloads" -maxdepth 1 \
         \( -iname "*${APP_NAME}*.dmg" -o -iname "*${APP_NAME}*.pkg" -o -iname "*${APP_NAME}*.zip" \) \
         -print0 2>/dev/null
)

# 7) Firefox site-storage entries that mention the app in the partition key
while IFS= read -r -d '' p; do MATCHES+=("$p"); done < <(
    find "$HOME/Library/Application Support/Firefox/Profiles" \
         -maxdepth 4 -iname "*${BUNDLE_LC}*" -print0 2>/dev/null
)

# ---------- deduplicate ----------
# Use a temp file + sort -u for portability (bash 3.2 on macOS lacks associative arrays).
if ((${#MATCHES[@]})); then
    TMPFILE="$(mktemp)"
    printf '%s\n' "${MATCHES[@]}" | sort -u > "$TMPFILE"
    MATCHES=()
    while IFS= read -r line; do MATCHES+=("$line"); done < "$TMPFILE"
    rm -f "$TMPFILE"
fi

# ---------- report ----------
if ((${#MATCHES[@]} == 0)); then
    warn "No files or folders matching \"$APP_NAME\" were found."
    exit 0
fi

printf '%sFound %d item(s):%s\n\n' "$BLD" "${#MATCHES[@]}" "$RST"
i=1
for p in "${MATCHES[@]}"; do
    printf '  %2d) %s\n' "$i" "$p"
    ((i++))
done
echo

# ---------- confirm ----------
if ! ask_yes_no "${BLD}Delete ALL of the above?${RST}"; then
    warn "Cancelled. Nothing was deleted."
    exit 0
fi

# ---------- running-process check ----------
PROC_PATTERN="$(printf '%s' "$APP_NAME" | tr -d ' ')"
if pgrep -fil "$PROC_PATTERN" >/dev/null 2>&1; then
    warn "A running process seems to match \"$APP_NAME\":"
    pgrep -fil "$PROC_PATTERN"
    if ask_yes_no "Kill it before deleting?"; then
        pkill -fil "$PROC_PATTERN" 2>/dev/null
        sleep 1
    fi
fi

# ---------- delete ----------
printf '\n'
NEED_SUDO=0
for p in "${MATCHES[@]}"; do
    case "$p" in
        /Library/*|/Applications/*) NEED_SUDO=1 ;;
    esac
done

SUDO=""
if ((NEED_SUDO)); then
    info "Some items are outside your home folder — sudo will be used for those."
    SUDO="sudo"
fi

FAILED=()
for p in "${MATCHES[@]}"; do
    if [[ "$p" == /Library/* || "$p" == /Applications/* ]]; then
        if $SUDO rm -rf -- "$p"; then
            ok "Removed: $p"
        else
            err "Failed:  $p"
            FAILED+=("$p")
        fi
    else
        if rm -rf -- "$p"; then
            ok "Removed: $p"
        else
            err "Failed:  $p"
            FAILED+=("$p")
        fi
    fi
done

# ---------- refresh Launch Services ----------
info "Refreshing Launch Services database ..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user 2>/dev/null
ok "Done."

# ---------- summary ----------
printf '\n%sSummary%s\n' "$BLD" "$RST"
printf '  Removed : %d\n' "$(( ${#MATCHES[@]} - ${#FAILED[@]} ))"
printf '  Failed  : %d\n' "${#FAILED[@]}"
if ((${#FAILED[@]})); then
    printf '\nFailed items:\n'
    for p in "${FAILED[@]}"; do printf '  - %s\n' "$p"; done
fi

printf '\n%sFinished.%s\n' "$BLD" "$RST"

# How to use it
# chmod +x remove_macosx_app.sh
# ./remove_macosx_app.sh

# It will prompt:
# Enter the name of the app to remove (e.g. JDownloader): 

# Type e.g. JDownloader (or Firefox, Slack, etc.), press Enter, and it will:
#     Search /Applications, ~/Applications, user ~/Library/*, system /Library/*, ~/.<app> dotfiles, ~/Downloads installers, and Firefox site storage.
#     Show a numbered list of everything it found.
#     Ask for confirmation.
#     Offer to kill any running process that matches the name.
#     Delete everything (using sudo only for /Library/* and /Applications/*).
#     Refresh Launch Services so Spotlight / Open-With menus are clean.
#     Print a summary with any failures.

# Notes
#     Case-insensitive matching (uses find -iname).
#     Bundle-id style leftovers like com.install4j.jdownloader2.6232.plist are caught via the BUNDLE_LC pass.
#     The Firefox partition-key paths (https+++www.google.com^partitionKey=%28...%29) are matched because they contain the app name in lowercase.
#     Works on macOS's default bash 3.2 (no associative arrays used).
#     Always review the list before confirming — a short name like Code could match unrelated things.

# If you want, I can also add a --dry-run flag or a --yes flag for non-interactive use.