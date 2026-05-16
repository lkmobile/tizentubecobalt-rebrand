#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR=$SCRIPT_DIR/bin
SDK_TOOLS_PATH="$BIN_DIR/android-sdk/build-tools"

if [ -d "$SDK_TOOLS_PATH" ]; then
    BUILD_TOOLS_DIR="$(find "$SDK_TOOLS_PATH" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
else
    BUILD_TOOLS_DIR=""
fi

if ! command -v apktool &> /dev/null; then
apktool() {
  java -jar "$(find "$BIN_DIR" -maxdepth 1 -name 'apktool*.jar' \
    | sort -V | tail -n1)" "$@"
}
fi

if ! command -v zipalign &> /dev/null; then
  zipalign() {
    ${BUILD_TOOLS_DIR}/zipalign "$@"
  }
fi

if ! command -v apksigner &> /dev/null; then
  apksigner() {
    ${BUILD_TOOLS_DIR}/apksigner "$@"
  }
fi

COBALT_FILE="$1"
COBALT_NAME="$(basename "${COBALT_FILE%.*}")"
COBALT_TMP=${COBALT_NAME}-tmp

# Clean old tmp
echo \* Clean old tmp

rm -rf ${COBALT_TMP}

# Decompile
echo \* Decompile ${COBALT_FILE}

apktool d ${COBALT_FILE} -o ${COBALT_TMP} 2>&1 | sed 's/^/  /'
# Change app name, id
echo \* Modify names in AndroidManifest.xml

sed -i \
  -e "s/io.gh.reisxd.tizentube.cobalt/com.google.android.youtube.tv/g" \
  -e "s/label=\"TizenTube\"/label=\"YouTube TV\"/g" \
  -e "s/debuggable=\"true\"/debuggable=\"false\"/g" \
  ${COBALT_TMP}/AndroidManifest.xml 2>&1 | sed 's/^/  /'

# Change app icons
echo \* Modify icons

(
  shopt -s nullglob

  for ICON in ${COBALT_TMP}/res/{drawable*,mipmap*}/{app_banner,app_banner.*,ic_app,ic_app.*}; do
    NEW_ICON_DIR="${ICON#*/}"
    echo "  $NEW_ICON_DIR"
    NEW_ICON_DIR="${SCRIPT_DIR}/icons/${NEW_ICON_DIR%/*}"

    cp $NEW_ICON_DIR/* $ICON

  done
)

# Recompile
echo \* Recompile
apktool b ${COBALT_TMP} -o ${COBALT_TMP}-unaligned.apk 2>&1 | sed 's/^/  /'

echo \* Align apk
zipalign -f 4 ${COBALT_TMP}-unaligned.apk ${COBALT_TMP}-aligned.apk

echo \* Sign apk
apksigner sign --ks ${SCRIPT_DIR}/debug.keystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android ${COBALT_TMP}-aligned.apk

echo \* Clean tmp
mv ${COBALT_TMP}-aligned.apk ${COBALT_NAME}-rebranded.apk
rm -rf ${COBALT_TMP}*
