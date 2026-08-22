#!/usr/bin/env python3
"""Overpass karolarini uygulamayla paketlenecek cami dosyasina cevirir.

    python3 Tools/mosque-extract/extract.py <karo-klasoru> <cikti.txt>

Cikti bicimi, satir basina bir cami:

    41.048123;28.933456;Eyup Sultan Camii

JSON yerine bu bicim kullaniliyor: 45 bin kayitta ayristirma yuku belirgin
sekilde daha az ve uygulama tarafi tek `split` ile okuyabiliyor.
"""
import json
import pathlib
import sys
import unicodedata

# Uygulamadaki `MosqueFinder.nameStems` ile ayni liste.
# OSM'de tekke, medrese ve turbeler de place_of_worship etiketli ve etiketleri
# gercek camilerden ayirt edilemiyor; ayirt eden tek sey ad.
NAME_STEMS = ("cami", "mescit", "mescid", "mosque", "masjid")

# Adsiz kayitlar icin gosterilecek etiket.
GENERIC_NAME = "Cami"


def fold(text):
    """Yerelden bagimsiz katlama: 'FATIH CAMII' ile 'cami' eslesmeli."""
    lowered = text.lower()
    return "".join(c for c in unicodedata.normalize("NFD", lowered)
                   if unicodedata.category(c) != "Mn")


def is_mosque(name):
    folded = fold(name)
    return any(stem in folded for stem in NAME_STEMS)


def coordinate(element):
    if "lat" in element and "lon" in element:
        return element["lat"], element["lon"]
    center = element.get("center")
    if center:
        return center["lat"], center["lon"]
    return None


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    tiles = sorted(pathlib.Path(sys.argv[1]).glob("karo-*.json"))
    if not tiles:
        print("karo dosyasi bulunamadi", file=sys.stderr)
        return 1

    seen = {}
    stats = {"okunan": 0, "adsiz_alindi": 0, "adsiz_elendi": 0,
             "cami_degil": 0, "tekrar": 0}

    for tile in tiles:
        try:
            elements = json.load(tile.open()).get("elements", [])
        except Exception as error:
            print(f"  {tile.name}: okunamadi ({error})", file=sys.stderr)
            continue
        for element in elements:
            stats["okunan"] += 1
            tags = element.get("tags") or {}
            name = tags.get("name") or tags.get("name:tr")

            if name:
                # Adi olan kayitta ad karar veriyor: tekke/medrese/turbe boylece
                # eleniyor (etiketleri gercek camiden ayirt edilemiyor).
                if not is_mosque(name):
                    stats["cami_degil"] += 1
                    continue
                label = name.replace(";", ",").replace("\n", " ").strip()
            else:
                # Adsiz kayitlarin %95'i building=mosque tasiyor: kirsalda cami
                # sik sik adsiz isaretleniyor. Bunlari atmak veri setinin yarisini
                # cope atmak demekti; building etiketi yeterli sinyal.
                if tags.get("building") != "mosque":
                    stats["adsiz_elendi"] += 1
                    continue
                stats["adsiz_alindi"] += 1
                label = GENERIC_NAME
            point = coordinate(element)
            if point is None:
                continue
            lat, lon = point
            # ~10 m'ye yuvarlanmis anahtarla tekilleştirme: karolar sinirlarda
            # ortusuyor ve ayni cami iki karoda birden cikiyor.
            key = (round(lat, 4), round(lon, 4))
            if key in seen:
                stats["tekrar"] += 1
                continue
            seen[key] = (lat, lon, label)

    # Enleme gore siralı: uygulamadaki kutu suzgeci boylece bellekte
    # birbirine yakin kayitlara dokunuyor.
    rows = sorted(seen.values(), key=lambda r: (r[0], r[1]))
    output = pathlib.Path(sys.argv[2])
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for lat, lon, name in rows:
            handle.write(f"{lat:.6f};{lon:.6f};{name}\n")

    size = output.stat().st_size
    print(f"karo sayisi        : {len(tiles)}")
    print(f"okunan eleman      : {stats['okunan']}")
    print(f"  adsiz, alinan    : {stats['adsiz_alindi']}  (building=mosque)")
    print(f"  adsiz, elenen    : {stats['adsiz_elendi']}")
    print(f"  adi cami degil   : {stats['cami_degil']}")
    print(f"  tekrar           : {stats['tekrar']}")
    print(f"yazilan cami       : {len(rows)}")
    print(f"dosya              : {output} ({size/1024/1024:.2f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
