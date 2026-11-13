#!/bin/sh
# Compila l'app e l'icona dentro "Calendario Widget.app".
set -e
cd "$(dirname "$0")"
APP="Calendario Widget.app/Contents"
mkdir -p "$APP/MacOS" "$APP/Resources"
swiftc -O Calendario.swift -o "$APP/MacOS/Calendario"

if [ ! -f "$APP/Resources/Calendario.icns" ]; then
  TMP=$(mktemp -d)
  swiftc icona.swift -o "$TMP/icona" && "$TMP/icona" "$TMP/icona.png"
  mkdir "$TMP/icon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icona.png" --out "$TMP/icon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/icona.png" --out "$TMP/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$TMP/icon.iconset" -o "$APP/Resources/Calendario.icns"
  rm -rf "$TMP"
fi
touch "Calendario Widget.app"
echo "Pronto: open \"Calendario Widget.app\""
