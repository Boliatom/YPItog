#!/usr/bin/env python3
"""Подрезка шрифтов Roboto до символов, которые нужны приложению (ПР6, п. 13).

Полный Roboto содержит около тысячи трёхсот знаков: греческий, вьетнамский,
расширенную латиницу и кириллицу. Интерфейс на русском языке использует
латиницу, кириллицу, цифры и знаки препинания. Остальное только увеличивает
размер файла, а шрифты скачиваются при первой загрузке страницы.

    python tool/fonts/subset.py

Исходные файлы лежат в tool/fonts/original/ (в приложение не попадают),
результат — в assets/fonts/. Нужен fontTools: pip install fonttools

Что оставлено:
  U+0020–007E        основная латиница, цифры, знаки
  U+00A0–00FF        неразрывный пробел, « » · № и европейская латиница
  U+0400–045F        русская кириллица (в том числе Ё, ё)
  U+0490–0491        Ґ ґ
  U+2010–2015        дефисы и тире
  U+2018–201E        кавычки
  U+2020–2022, 2026  кинжал, маркер списка, многоточие
  U+2030, 2032–2033  промилле, штрихи
  U+2039–203A        одинарные угловые кавычки
  U+20AC, 2116, 2122 €, №, ™
  U+2190–2193, 2212  стрелки, минус
"""
import os
import sys

from fontTools import subset

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SOURCE = os.path.join(ROOT, 'tool', 'fonts', 'original')
TARGET = os.path.join(ROOT, 'assets', 'fonts')

UNICODES = (
    'U+0020-007E,U+00A0-00FF,U+0400-045F,U+0490-0491,U+2010-2015,'
    'U+2018-201E,U+2020-2022,U+2026,U+2030,U+2032-2033,U+2039-203A,'
    'U+20AC,U+2116,U+2122,U+2190-2193,U+2212'
)

FILES = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']

def main() -> int:
    total_before = total_after = 0
    for name in FILES:
        src = os.path.join(SOURCE, name)
        dst = os.path.join(TARGET, name)
        if not os.path.exists(src):
            print(f'Нет исходного файла: {src}', file=sys.stderr)
            return 1
        args = [
            src,
            f'--unicodes={UNICODES}',
            f'--output-file={dst}',
            '--no-hinting',
            '--desubroutinize',
            '--layout-features=kern,liga,ccmp,locl,mark,mkmk',
        ]
        subset.main(args)
        before, after = os.path.getsize(src), os.path.getsize(dst)
        total_before += before
        total_after += after
        print(f'{name}: {before / 1024:.0f} КБ -> {after / 1024:.0f} КБ')
    print(f'Итого: {total_before / 1024:.0f} КБ -> {total_after / 1024:.0f} КБ')
    return 0

if __name__ == '__main__':
    sys.exit(main())
