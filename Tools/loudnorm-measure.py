#!/usr/bin/env python3
"""ffmpeg loudnorm'un birinci gecis cikisini ikinci gecis parametrelerine cevirir.

stdin: `loudnorm=...:print_format=json` calistirilmis ffmpeg'in stderr'i
stdout: `measured_I=..:measured_TP=..:...` seklinde filtre parametreleri

Ayri dosyada, cunku bu ayiklamayi kabuk icine gomulu tek satir python veya
sed/awk ile yapmak tirnak kacirma yuzunden surekli kiriliyor.
"""
import json
import re
import sys

PAIRS = [
    ("measured_I", "input_i"),
    ("measured_TP", "input_tp"),
    ("measured_LRA", "input_lra"),
    ("measured_thresh", "input_thresh"),
    ("offset", "target_offset"),
]


def main() -> int:
    blocks = re.findall(r"\{[^{}]*input_i[^{}]*\}", sys.stdin.read(), re.S)
    if not blocks:
        print("loudnorm olcum blogu bulunamadi", file=sys.stderr)
        return 1
    measured = json.loads(blocks[-1])
    try:
        parts = [name + "=" + str(measured[key]) for name, key in PAIRS]
    except KeyError as missing:
        print("olcumde eksik alan: " + str(missing), file=sys.stderr)
        return 1
    # loudnorm, olculen deger sonsuz gelirse (tamamen sessiz kesit) calismaz.
    if any("inf" in part for part in parts):
        print("kesit sessiz gorunuyor, seviye olculemedi", file=sys.stderr)
        return 1
    print(":".join(parts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
