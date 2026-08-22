#!/bin/sh
# Kaynak ses dosyasini iOS bildirim sesine cevirir.
#
#   Tools/make-sound.sh ezan.mp3 ezan-yeni [baslangic] [sure]
#
# iOS bildirim sesi kurallari: Linear PCM / IMA4 / uLaw / aLaw codec, .caf/.aiff/.wav
# konteyner, en fazla 30 saniye. MP3 ve M4A dogrudan kullanilamaz. 30 saniyeyi gecen
# dosyalarda iOS hata vermeden sistem sesine duser.
#
# Ses seviyesi iki gecisli loudnorm ile -16 LUFS'a getiriliyor; boylece farkli
# kaynaklardan gelen sesler ayni yuksekligde caliyor. Sonda 0.4 sn fade var,
# kesme yerinin ani kopmamasi icin.
#
# Kesim noktasini ifade sinirina oturtmak icin once bosluklari gor:
#   ffmpeg -i girdi.mp3 -af silencedetect=noise=-32dB:d=0.30 -f null - 2>&1 | grep silence_
set -e

IN="$1"; NAME="$2"; START="${3:-0}"; DUR="$4"
LIMIT=30

if [ -z "$IN" ] || [ -z "$NAME" ]; then
    echo "kullanim: $0 <girdi> <cikti-adi> [baslangic-sn] [sure-sn]" >&2
    exit 1
fi
[ -f "$IN" ] || { echo "hata: '$IN' bulunamadi" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "hata: ffmpeg gerekli (brew install ffmpeg)" >&2; exit 1; }

TOTAL=$(afinfo "$IN" | awk -F': ' '/estimated duration/ {print $2}' | awk '{print $1}')
if [ -z "$DUR" ]; then
    DUR=$(awk -v t="$TOTAL" -v s="$START" -v l="$LIMIT" 'BEGIN{d=t-s; print (d>l-0.5? l-0.5 : d)}')
fi
awk -v d="$DUR" -v l="$LIMIT" 'BEGIN{exit !(d>=l)}' && {
    echo "hata: sure ${DUR} sn, iOS siniri ${LIMIT} sn altinda olmali" >&2; exit 1; }

DEST="$(cd "$(dirname "$0")/.." && pwd)/EzanVakti/$NAME.caf"
TMP=$(mktemp -t ezansound).wav
FADE=$(awk -v d="$DUR" 'BEGIN{printf "%.2f", d-0.4}')

echo "kaynak ${TOTAL} sn -> kesit ${START}..$(awk -v a="$START" -v b="$DUR" 'BEGIN{printf "%.2f", a+b}') sn"

# 1. gecis: seviyeyi olc
MEASURED=$(ffmpeg -hide_banner -nostdin -y -ss "$START" -t "$DUR" -i "$IN" \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null /dev/null 2>&1 \
    | python3 "$(dirname "$0")/loudnorm-measure.py") || {
        echo "hata: ses seviyesi olculemedi" >&2; exit 1; }

# 2. gecis: uygula
ffmpeg -hide_banner -nostdin -y -loglevel error -ss "$START" -t "$DUR" -i "$IN" \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11:${MEASURED}:linear=true,afade=t=out:st=${FADE}:d=0.4" \
    -ar 44100 "$TMP"

rm -f "$DEST"
afconvert "$TMP" "$DEST" -d ima4 -f caff
rm -f "$TMP"

echo
echo "yazildi: $DEST"
afinfo "$DEST" | grep -E "Data format|estimated duration"
echo
echo "Xcode'da yeniden derle, sonra Bildirimler ekranindan '$NAME' sesini sec."
echo "NOT: yeni ad kullandiysan NotificationSoundCatalog.all listesine eklemelisin."
