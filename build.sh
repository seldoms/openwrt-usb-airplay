#!/bin/sh
# Run on the Mac host with Docker. Dependencies stay inside the build container.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
docker run --rm --platform linux/arm64 -v "$ROOT:/work" -w /work alpine:3.22 sh -eu -c '
 apk add --no-cache build-base linux-headers libusb-dev soxr-dev avahi-dev openssl-dev libconfig-dev popt-dev autoconf automake libtool git
 mkdir -p build dist/lib
 cc -O2 -pthread -std=gnu99 -Isrc/libmaru src/libmaru/libmaru.c src/libmaru/fifo.c src/player.c -lusb-1.0 -lsoxr -lm -o dist/maru-player
 if [ ! -d build/shairport-sync ]; then
   git clone https://github.com/mikebrady/shairport-sync.git build/shairport-sync
 fi
 cd build/shairport-sync
 git checkout --detach 046b59851315f706d8e449fb9305e9f029811a71
 autoreconf -fi
 ./configure --with-os=linux --with-stdout --with-ssl=openssl --with-soxr --with-avahi --sysconfdir=/opt/airplay-usb
 make -j4
 cp shairport-sync /work/dist/
 cd /work
 cp -L /usr/lib/libusb-1.0.so.0 /usr/lib/libsoxr.so.0 /usr/lib/libcrypto.so.3 /usr/lib/libconfig.so.11 /usr/lib/libpopt.so.0 /usr/lib/libgomp.so.1 dist/lib/
 cp openwrt/airplay.conf openwrt/run.sh dist/
'
