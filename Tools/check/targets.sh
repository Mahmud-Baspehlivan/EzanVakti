#!/bin/sh
# Her hedefi KENDI dosya kumesiyle, KENDI SDK'siyla derler.
#
#   Tools/check/targets.sh
#
# Neden dosya kumesi: butun dosyalari tek klasore koyup derlemek hedef uyeligi
# hatalarini gizliyor. Gercek ornek: Palette.swift widget hedefine eklendi ama
# bagli oldugu ScaledFont.swift eklenmedi; duz denetim gecti, Xcode patladi.
# pbxproj'daki membershipExceptions tek dogruluk kaynagi, betik elle guncellenmiyor.
#
# Neden gercek SDK: onceki surum her seyi macOS'a karsi derliyordu ve macOS'ta
# olmayan her sey (ActivityKit, .accessory* aileleri, widgetLabel, UIKit) ya
# kaynaktan kirpiliyor ya da dosya tamamen atiliyordu. Yani en platforma ozel
# kod, yani en cok denetime muhtac olan kod, hic denetlenmiyordu. iOS ve watchOS
# SDK'lariyla derleyince kirpmaya gerek kalmadi: kaynak oldugu gibi gidiyor.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

IOS_SDK=$(xcrun --show-sdk-path --sdk iphoneos)
WATCH_SDK=$(xcrun --show-sdk-path --sdk watchos)
IOS_MIN=$(grep -o "IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*" EzanVakti.xcodeproj/project.pbxproj \
          | awk '{print $3}' | sort -V | head -1)
WATCH_MIN=$(grep -o "WATCHOS_DEPLOYMENT_TARGET = [0-9.]*" EzanVakti.xcodeproj/project.pbxproj \
            | awk '{print $3}' | sort -V | head -1)

# pbxproj'dan bir hedefin paylasilan dosyalarini oku (membershipExceptions).
shared_for() {   # <hedef-adi-parcasi>
    python3 - "$1" <<'PY'
import json, subprocess, sys
needle = sys.argv[1]
j = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", "EzanVakti.xcodeproj/project.pbxproj"]))
o = j["objects"]
for v in o.values():
    if v.get("isa") != "PBXFileSystemSynchronizedBuildFileExceptionSet": continue
    t = v.get("target")
    if t not in o or needle not in (o[t].get("name") or ""): continue
    for path in sorted(v.get("membershipExceptions") or []):
        if path.endswith(".swift"):
            print("EzanVakti/" + path)
PY
}

check() {   # <baslik> <target-triple> <sdk> <dosyalar...>
    title="$1"; triple="$2"; sdk="$3"; shift 3
    dir="/tmp/check-$(echo "$title" | tr ' ' '-')"
    rm -rf "$dir"; mkdir -p "$dir"
    for f in "$@"; do cp "$f" "$dir/"; done
    ( cd "$dir" && swiftc -typecheck -swift-version 5 -target "$triple" -sdk "$sdk" *.swift )
    echo "  OK ($(ls "$dir"/*.swift | wc -l | tr -d ' ') dosya)"
}

echo "== uygulama hedefi (iOS $IOS_MIN) =="
check "app" "arm64-apple-ios$IOS_MIN" "$IOS_SDK" \
    EzanVakti/EzanVaktiApp.swift EzanVakti/Core/*.swift EzanVakti/Services/*.swift \
    EzanVakti/Features/*.swift EzanVakti/Features/*/*.swift

echo "== widget hedefi (iOS $IOS_MIN) =="
check "widget" "arm64-apple-ios$IOS_MIN" "$IOS_SDK" \
    EzanVaktiWidget/*.swift $(shared_for "Widget")

echo "== saat uygulamasi (watchOS $WATCH_MIN) =="
check "watch-app" "arm64-apple-watchos$WATCH_MIN" "$WATCH_SDK" \
    "EzanVaktiWatch Watch App"/*.swift $(shared_for "Watch App")

# Komplikasyon hedefi henuz Xcode'da olusturulmadi; kaynaklari
# WatchComplicationSources'ta bekliyor. Dosya kumesi elle yaziliyor, hedef
# acilinca membershipExceptions'tan okunacak.
echo "== saat komplikasyonu (hedef bekliyor) (watchOS $WATCH_MIN) =="
check "watch-comp" "arm64-apple-watchos$WATCH_MIN" "$WATCH_SDK" \
    WatchComplicationSources/*.swift EzanVaktiWidget/PrayerWidgetEntry.swift \
    $(shared_for "Watch App")
