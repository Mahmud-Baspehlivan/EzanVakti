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
#
# Yol oneki sabit degil: her istisna kumesi onu referans eden senkron kok
# grubun klasorune goredir. Komplikasyon hedefi hem EzanVakti hem
# EzanVaktiWidget klasorunden dosya aliyor.
shared_for() {   # <hedef-adi-parcasi>
    python3 - "$1" <<'PY'
import json, subprocess, sys
needle = sys.argv[1]
j = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", "EzanVakti.xcodeproj/project.pbxproj"]))
o = j["objects"]
owner = {}   # istisna kumesi id -> klasor yolu
for v in o.values():
    if v.get("isa") != "PBXFileSystemSynchronizedRootGroup": continue
    for e in v.get("exceptions") or []:
        owner[e] = v.get("path")
for k, v in o.items():
    if v.get("isa") != "PBXFileSystemSynchronizedBuildFileExceptionSet": continue
    t = v.get("target")
    if t not in o or needle not in (o[t].get("name") or ""): continue
    folder = owner.get(k)
    if not folder: continue
    for path in sorted(v.get("membershipExceptions") or []):
        if path.endswith(".swift"):
            print(f"{folder}/{path}")
PY
}

# Bir hedefin SWIFT_DEFAULT_ACTOR_ISOLATION ayarini pbxproj'dan oku.
#
# Neden: bu ayar acikken kod varsayilan olarak MainActor'a baglaniyor, swiftc
# varsayilanda baglamiyor. Aradaki fark tam da bu betigin kapatmak icin var
# oldugu turden: denetim gecer, Xcode patlar. Ayar hedefe gore degistigi icin
# sabit yazilamiyor, pbxproj tek dogruluk kaynagi.
isolation_for() {   # <hedef-adi-parcasi>
    python3 - "$1" <<'ISO'
import json, subprocess, sys
needle = sys.argv[1]
j = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", "EzanVakti.xcodeproj/project.pbxproj"]))
o = j["objects"]
for t in o.values():
    # TAM ad eslesmesi: "EzanVakti" alt dizgesi dort hedeften ucune uyuyor ve
    # ilk bulunan degeri donmek komsu hedefin ayarini yanlislikla uygulatiyordu.
    if t.get("isa") != "PBXNativeTarget" or (t.get("name") or "") != needle:
        continue
    lst = o.get(t.get("buildConfigurationList"), {})
    values = set()
    for cfg in lst.get("buildConfigurations") or []:
        v = (o.get(cfg, {}).get("buildSettings") or {}).get("SWIFT_DEFAULT_ACTOR_ISOLATION")
        values.add(v or "")
    # Debug ile Release ayrisirsa denetim hangisini temsil ettigini soyleyemez.
    if len(values) > 1:
        sys.stderr.write(f"{needle}: SWIFT_DEFAULT_ACTOR_ISOLATION yapilandirmalar arasi tutarsiz {values}\n")
        sys.exit(1)
    print(values.pop() if values else "")
    sys.exit()
ISO
}

check() {   # <baslik> <target-triple> <sdk> <izolasyon|bos> <dosyalar...>
    title="$1"; triple="$2"; sdk="$3"; isolation="$4"; shift 4
    iso_flag=""
    [ -n "$isolation" ] && iso_flag="-default-isolation $isolation"
    dir="/tmp/check-$(echo "$title" | tr ' ' '-')"
    rm -rf "$dir"; mkdir -p "$dir"
    for f in "$@"; do cp "$f" "$dir/"; done
    # MemberImportVisibility: Xcode bu tanilamayi aciyor, swiftc varsayilanda
    # acmiyordu. Aradaki fark gercek bir hatayi kacirdi — WatchComplicationViews
    # widgetLabel kullaniyordu ama WidgetKit'i import etmiyordu; ayni modulde
    # baska bir dosya import ettigi icin denetim geciyor, Xcode patliyordu.
    ( cd "$dir" && swiftc -typecheck -swift-version 5 \
        -enable-upcoming-feature MemberImportVisibility \
        $iso_flag \
        -target "$triple" -sdk "$sdk" *.swift )
    echo "  OK ($(ls "$dir"/*.swift | wc -l | tr -d ' ') dosya${isolation:+, izolasyon $isolation})"
}

echo "== uygulama hedefi (iOS $IOS_MIN) =="
check "app" "arm64-apple-ios$IOS_MIN" "$IOS_SDK" "$(isolation_for "EzanVakti")" \
    EzanVakti/EzanVaktiApp.swift EzanVakti/Core/*.swift EzanVakti/Services/*.swift \
    EzanVakti/Features/*.swift EzanVakti/Features/*/*.swift

echo "== widget hedefi (iOS $IOS_MIN) =="
check "widget" "arm64-apple-ios$IOS_MIN" "$IOS_SDK" "$(isolation_for "EzanVaktiWidgetExtension")" \
    EzanVaktiWidget/*.swift $(shared_for "Widget")

echo "== saat uygulamasi (watchOS $WATCH_MIN) =="
check "watch-app" "arm64-apple-watchos$WATCH_MIN" "$WATCH_SDK" "$(isolation_for "EzanVaktiWatch Watch App")" \
    "EzanVaktiWatch Watch App"/*.swift $(shared_for "Watch App")

echo "== saat komplikasyonu (watchOS $WATCH_MIN) =="
check "watch-comp" "arm64-apple-watchos$WATCH_MIN" "$WATCH_SDK" "$(isolation_for "watch widgetExtension")" \
    "watch widget"/*.swift $(shared_for "watch widgetExtension")
