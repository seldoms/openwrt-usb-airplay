#!/bin/sh
# Install on OpenWrt; preserve configuration and archive an existing installation.
set -eu
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
[ "$(uname -m)" = aarch64 ] || { echo 'Requires aarch64'; exit 1; }
[ -e /lib/ld-musl-aarch64.so.1 ] && [ -f /etc/rc.common ] || { echo 'Requires musl OpenWrt'; exit 1; }
for tool in flock sha256sum tar; do command -v "$tool" >/dev/null || exit 1; done
[ -r /usr/lib/libavahi-client.so.3 ] && [ -r /usr/lib/libavahi-common.so.3 ] || { echo 'Install and enable Avahi first'; exit 1; }
sha256sum -c SHA256SUMS
LD_LIBRARY_PATH="$PWD/app/lib" ./app/shairport-sync -V
backup=/opt/airplay-usb-backups/$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$backup"
[ ! -f /etc/sysupgrade.conf ] || cp -p /etc/sysupgrade.conf "$backup/"
[ ! -f /etc/init.d/airplay-usb ] || cp -p /etc/init.d/airplay-usb "$backup/airplay-usb.init"
if [ -d /opt/airplay-usb ]; then
    tar -czf "$backup/previous.tar.gz" -C /opt airplay-usb
    [ ! -f /opt/airplay-usb/airplay.conf ] || cp -p /opt/airplay-usb/airplay.conf "$backup/airplay.conf"
fi
[ ! -x /etc/init.d/airplay-usb ] || /etc/init.d/airplay-usb stop
mkdir -p /opt/airplay-usb
cp -R app/. /opt/airplay-usb/
[ ! -f "$backup/airplay.conf" ] || cp -p "$backup/airplay.conf" /opt/airplay-usb/airplay.conf
cp airplay-usb.init /etc/init.d/airplay-usb
chmod 700 /opt/airplay-usb/run.sh /opt/airplay-usb/maru-player /opt/airplay-usb/shairport-sync /etc/init.d/airplay-usb
chmod 600 /opt/airplay-usb/airplay.conf
for path in /opt/airplay-usb/ /etc/init.d/airplay-usb; do
    grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >>/etc/sysupgrade.conf
done
/etc/init.d/airplay-usb enable
/etc/init.d/airplay-usb start
echo "Installed. Backup: $backup. Run /etc/init.d/airplay-usb status; cold boot and playback require separate verification."
