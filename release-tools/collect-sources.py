#!/usr/bin/env python3
"""Collect dependency source archives and pinned Alpine packaging recipes."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import urllib.request
OUT = Path('releases/source-inputs')
OUT.mkdir(parents=True, exist_ok=True)
FILES = ['libusb-1.0.28.tar.bz2', 'soxr-0.1.3.tar.xz', 'libconfig-1.7.3.tar.gz', 'popt-1.19.tar.gz', 'openssl-3.5.9.tar.gz', 'gcc-14.2.0.tar.xz']
APORTS = '96cd526538b0d59dc214206adc3c94c3654d7011'
def fetch(item):
    name, url = item
    path = OUT / name
    if not path.exists():
        tmp = path.with_suffix(path.suffix + '.part')
        with urllib.request.urlopen(url, timeout=90) as response, tmp.open('wb') as target:
            while block := response.read(1024 * 1024):
                target.write(block)
        tmp.rename(path)
    print(name, path.stat().st_size, flush=True)
    return f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {name}\n'
items = [(name, f'https://distfiles.alpinelinux.org/distfiles/v3.22/{name}') for name in FILES]
items.append((f'aports-{APORTS}.tar.gz', f'https://codeload.github.com/alpinelinux/aports/tar.gz/{APORTS}'))
with ThreadPoolExecutor(max_workers=4) as pool:
    sums = list(pool.map(fetch, items))
(OUT / 'SHA256SUMS').write_text(''.join(sums))
