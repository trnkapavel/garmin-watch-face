#!/bin/bash
# Spustí Garmin Connect IQ simulátor (vyber nejnovější SDK)

SDK_ROOT="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
if [ ! -d "$SDK_ROOT" ]; then
  echo "Složka SDK nenalezena: $SDK_ROOT"
  exit 1
fi

# Nejnovější SDK (podle data ve jménu)
LATEST=$(ls -1 "$SDK_ROOT" 2>/dev/null | grep "^connectiq-sdk" | sort -V | tail -1)
if [ -z "$LATEST" ]; then
  echo "Žádné Connect IQ SDK v: $SDK_ROOT"
  exit 1
fi

BIN="$SDK_ROOT/$LATEST/bin"
APP="$BIN/ConnectIQ.app"
SIM="$APP/Contents/MacOS/simulator"

if [ -x "$SIM" ]; then
  echo "Spouštím simulátor: $LATEST"
  # Na některých Macách open -a selhává (kLSNoExecutableErr), proto zkusíme přímo binárku
  if ! open -a "$APP" 2>/dev/null; then
    echo "Spouštím přímo: $SIM"
    "$SIM" &
  fi
elif [ -f "$BIN/connectiq" ]; then
  echo "Spouštím: $BIN/connectiq"
  "$BIN/connectiq"
else
  echo "Simulátor nenalezen v: $BIN"
  exit 1
fi
