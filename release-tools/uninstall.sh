#!/bin/sh
# Disable service and archive files instead of deleting user configuration.
set -eu
[ "$(id -u)" = 0 ] || exit 1
backup=/opt/airplay-usb-backups/uninstall-$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$backup"
if [ -x /etc/init.d/airplay-usb ]; then
    /etc/init.d/airplay-usb stop
    /etc/init.d/airplay-usb disable
    mv /etc/init.d/airplay-usb "$backup/airplay-usb.init"
fi
[ ! -d /opt/airplay-usb ] || mv /opt/airplay-usb "$backup/app"
echo "Disabled and archived to $backup. sysupgrade preservation entries retained."
