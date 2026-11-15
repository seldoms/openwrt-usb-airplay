#!/bin/sh
# Keep receiver and USB output in one supervised lifecycle.
set -u
APP=/opt/airplay-usb
export LD_LIBRARY_PATH="$APP/lib"
mkdir -p /var/run/airplay-usb
exec 9>/var/run/airplay-usb/service.lock
flock -n 9 || exit 1
FIFO=/var/run/airplay-usb/audio.pcm
[ -p "$FIFO" ] || mkfifo -m 600 "$FIFO" || exit 1
receiver=
player=
cleanup() {
    trap - TERM INT EXIT
    [ -z "$receiver" ] || kill -TERM "$receiver" 2>/dev/null
    [ -z "$player" ] || kill -TERM "$player" 2>/dev/null
    wait 2>/dev/null
}
trap 'exit 0' TERM INT
trap cleanup EXIT
usb_present() {
    for dev in /sys/bus/usb/devices/*; do
        [ -r "$dev/idVendor" ] && [ -r "$dev/idProduct" ] || continue
        [ "$(cat "$dev/idVendor")" = e5b7 ] &&
        [ "$(cat "$dev/idProduct")" = 0811 ] && return 0
    done
    return 1
}
while ! usb_present; do sleep 3; done
"$APP/maru-player" <"$FIFO" 9>&- &
player=$!
"$APP/shairport-sync" -c "$APP/airplay.conf" >"$FIFO" 9>&- &
receiver=$!
while kill -0 "$receiver" 2>/dev/null && kill -0 "$player" 2>/dev/null; do
    usb_present || exit 1
    sleep 3
done
exit 1
