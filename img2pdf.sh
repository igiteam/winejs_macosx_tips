cd "/Users/gabrielmay/Documents/the-agent-film-production/The_Agent_A4_Double_Paged/TheAgent1952"

read -r -p "Portrait or landscape? [p/l]: " ORIENT
case "$ORIENT" in
  p|P|portrait)   W=2480; H=3508 ;;   # A4 portrait  @ 300 DPI
  l|L|landscape)  W=3508; H=2480 ;;   # A4 landscape @ 300 DPI
  *) echo "Enter p or l"; exit 1 ;;
esac

DPI=300

mkdir -p _ordered && rm -f _ordered/*
i=1
for f in The_Agent.png The_Agent\(*.png; do
  printf -v n "%03d" "$i"
  sips --resampleHeightWidth "$H" "$W" "$f" --out "_ordered/page_$n.png" >/dev/null
  i=$((i+1))
done

mkdir -p _pdfs && rm -f _pdfs/*
for f in _ordered/*.png; do
  sips -s format pdf -s dpiHeight "$DPI" -s dpiWidth "$DPI" \
       "$f" --out "_pdfs/$(basename "${f%.png}").pdf" >/dev/null
done

/System/Library/Automator/Combine\ PDF\ Pages.action/Contents/MacOS/join \
  -o The_Agent.pdf _pdfs/*.pdf

rm -rf _ordered _pdfs