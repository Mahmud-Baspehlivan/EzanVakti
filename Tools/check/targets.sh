#!/bin/sh
# Her hedefi KENDI dosya kumesiyle derler.
#
#   Tools/check/targets.sh
#
# Neden gerekli: butun dosyalari tek klasore kopyalayip derlemek hedef uyeligi
# hatalarini gizliyor. Gercek bir ornek: Palette.swift widget hedefine eklendi
# ama bagli oldugu ScaledFont.swift eklenmedi; duz denetim gecti, Xcode patladi.
#
# pbxproj'daki membershipExceptions listesi tek dogruluk kaynagi olarak okunuyor,
# yani bu betik elle guncellenmiyor.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

prepare() {   # <hedef-klasor> <dosyalar...>
    dir="$1"; shift
    rm -rf "$dir"; mkdir -p "$dir"
    for f in "$@"; do cp "$f" "$dir/"; done
    python3 - "$dir" <<'PY'
import glob, re, sys
for f in glob.glob(sys.argv[1] + "/*.swift"):
    s = open(f).read()
    i = s.find("#Preview {")
    if i >= 0: s = s[:i]
    # macOS'ta olmayan iOS-only cagrilar; gercek kod degismiyor
    s = s.replace("manager.stopUpdatingHeading()", "// iOS-only")
    s = s.replace("manager.startUpdatingHeading()", "// iOS-only")
    s = re.sub(r"\n\s*\.navigationBarTitleDisplayMode\([^)]*\)", "", s)
    s = re.sub(r"MapAppLauncher\.openDirections\([^)]*\)", "()", s)
    s = s.replace("availableMapApps = MapAppLauncher.available",
                  "availableMapApps = MapApp.allCases")
    # Saat komplikasyon aileleri ve kilit ekrani widget aileleri platforma ozel
    s = s.replace(".accessoryCircular, .accessoryCorner,", "")
    s = s.replace(".accessoryRectangular, .accessoryInline,", "")
    # Kilit ekrani widget aileleri ve .accessory* dallari iOS'a ozel
    s = s.replace(".accessoryInline, .accessoryCircular, .accessoryRectangular,\n", "")
    s = re.sub(r"case \.accessory\w+:\n(\s+.*\n)+?(?=\s+case |\s+default)", "", s)
    s = s.replace(".containerBackground(.clear, for: .widget)", "")
    # ActivityKit dosyalari denetimden cikariliyor; onlara yapilan referans da
    s = re.sub(r"\n\s*PrayerLiveActivity\(\)", "", s)
    s = re.sub(r"\n\s*await refreshLiveActivity\(\)", "", s)
    s = re.sub(r"(?s)\n\s*/// Live Activity arka planda.*?\n    \}\n", "\n", s)
    open(f, "w").write(s)
PY

    # ActivityKit yalnizca iOS'ta var; bu dosyalar macOS denetiminden cikariliyor.
    # Onlari tuketen gorunumler (PrayerLiveActivityViews) saf SwiftUI oldugu
    # icin denetimde kaliyor.
    for f in "$dir"/*.swift; do
        if grep -q "import ActivityKit" "$f" 2>/dev/null; then rm -f "$f"; fi
    done
}

echo "== widget hedefi =="
WIDGET_SHARED=$(python3 - <<'PY'
import json, subprocess
j = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", "EzanVakti.xcodeproj/project.pbxproj"]))
o = j["objects"]
for v in o.values():
    if v.get("isa") != "PBXFileSystemSynchronizedBuildFileExceptionSet": continue
    t = v.get("target")
    if t not in o or "Widget" not in (o[t].get("name") or ""): continue
    for path in v.get("membershipExceptions") or []:
        if path.endswith(".swift"):
            print("EzanVakti/" + path)
PY
)
prepare /tmp/check-widget EzanVaktiWidget/*.swift $WIDGET_SHARED
( cd /tmp/check-widget && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift )
echo "  OK ($(ls /tmp/check-widget/*.swift | wc -l | tr -d ' ') dosya)"

echo "== uygulama hedefi =="
prepare /tmp/check-app EzanVakti/Core/*.swift EzanVakti/Services/*.swift \
        EzanVakti/Features/*.swift EzanVakti/Features/*/*.swift EzanVakti/EzanVaktiApp.swift
rm -f /tmp/check-app/MapAppLauncher.swift   # UIKit, macOS'ta yok
( cd /tmp/check-app && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift )
echo "  OK ($(ls /tmp/check-app/*.swift | wc -l | tr -d ' ') dosya)"

# Saat uygulamasi projede var; paylasilan dosyalari pbxproj'dan okuyoruz.
# Komplikasyon hedefi henuz olusturulmadi, kaynaklari WatchComplicationSources'ta
# bekliyor ve elle kuruluyor.
echo "== saat uygulamasi =="
WATCH_SHARED=$(python3 - <<'PYEOF'
import json, subprocess
j = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", "EzanVakti.xcodeproj/project.pbxproj"]))
o = j["objects"]
for v in o.values():
    if v.get("isa") != "PBXFileSystemSynchronizedBuildFileExceptionSet": continue
    t = v.get("target")
    if t not in o or "Watch App" not in (o[t].get("name") or ""): continue
    for path in v.get("membershipExceptions") or []:
        if path.endswith(".swift"):
            print("EzanVakti/" + path)
PYEOF
)
prepare /tmp/check-watch-app $WATCH_SHARED "EzanVaktiWatch Watch App"/*.swift
( cd /tmp/check-watch-app && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift )
echo "  OK ($(ls /tmp/check-watch-app/*.swift | wc -l | tr -d ' ') dosya)"

echo "== saat komplikasyonu (hedef bekliyor) =="
prepare /tmp/check-watch-comp $WATCH_SHARED \
    WatchComplicationSources/*.swift EzanVaktiWidget/PrayerWidgetEntry.swift
( cd /tmp/check-watch-comp && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift )
echo "  OK ($(ls /tmp/check-watch-comp/*.swift | wc -l | tr -d ' ') dosya)"
