# Thanks for confirming. That Terminal one-liner from Joepher is a solid fix for this Sonoma bug:
# bash
rm -f "${HOME}/Desktop/.DS_Store" && defaults delete com.apple.finder DesktopViewSettings && killall Finder