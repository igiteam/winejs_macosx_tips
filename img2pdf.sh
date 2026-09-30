#!/bin/bash

cd "$(dirname "$0")"

read -r -p "Portrait or landscape? [p/l]: " ORIENT
case "$ORIENT" in
  p|P|portrait)   W=2480; H=3508 ;;
  l|L|landscape)  W=3508; H=2480 ;;
  *) echo "Enter p or l"; exit 1 ;;
esac

DPI=300
OUTPUT="$(basename "$(pwd)").pdf"
echo "📄 Output: $OUTPUT"

mkdir -p _ordered && rm -f _ordered/*

# Find the base file (no brackets) first, then the numbered files
shopt -s nullglob

BASE=""
for f in *.png *.jpg *.jpeg; do
  if [[ ! "$f" =~ \( ]]; then
    BASE="${f%.*}"
    break
  fi
done

if [ -z "$BASE" ]; then
  echo "❌ No base image found"
  exit 1
fi

echo "📄 Base: $BASE"
echo "📄 Numbered: ${BASE}(0)..."

# Build the ordered list: base first, then numbered
FILES=("$BASE".*)
for f in "$BASE"\(*.png "$BASE"\(*.jpg "$BASE"\(*.jpeg; do
  FILES+=("$f")
done

# Sort the numbered ones naturally
ORDERED=("${FILES[0]}")
NUMBERED=("${FILES[@]:1}")
while IFS= read -r -d '' f; do
  ORDERED+=("$f")
done < <(printf '%s\0' "${NUMBERED[@]}" | sort -zV)

i=1
for f in "${ORDERED[@]}"; do
  printf -v n "%03d" "$i"
  sips --resampleHeightWidth "$H" "$W" "$f" --out "_ordered/page_$n.png" >/dev/null
  i=$((i+1))
done

mkdir -p _pdfs && rm -f _pdfs/*
for f in _ordered/*.png; do
  sips -s format pdf -s dpiHeight "$DPI" -s dpiWidth "$DPI" \
       "$f" --out "_pdfs/$(basename "${f%.png}").pdf" >/dev/null
done

# -- Merge via macOS Automator join --
/System/Library/Automator/Combine\ PDF\ Pages.action/Contents/MacOS/join \
  -o "$OUTPUT" _pdfs/*.pdf

# -- Cleanup --
rm -rf _ordered _pdfs

echo "✅ Done: $OUTPUT"
echo "📦 Size: $(du -h "$OUTPUT" | cut -f1)"