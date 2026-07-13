#!/bin/bash
set -euo pipefail

: "${VERSION:=dev}"
DATE=$(date +%Y%m%d)
ARCH=$(uname -m)

ENABLE_binfmt="false"
BUILD_KDE=""
BUILD_XFCE=""
BUILD_KDE_plus="false"
BUILD_XFCE_plus="false"
ENABLE_nosnap="false"
PulseAudio=""
ENABLE_zh_tz=""
ENABLE_yj=""
ENABLE_mesa=""
ENABLE_kfgj=""
ENABLE_zip=""
ENABLE_docker=""
ENABLE_srf=""
ENABLE_tmoe=""
USERNAME="Gold"
DOCKERFILE=""

usage() {
  echo "Usage: $0 -i <template.Dockerfile> [-v <version>] [-K min|conc|none] [-L true|false] [-P socket|tcp|none] ..."
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -i) DOCKERFILE="$2"; shift 2 ;;
    -v) VERSION="$2"; shift 2 ;;
    -K) BUILD_KDE="$2"; BUILD_XFCE="$2"; shift 2 ;;
    -L) BUILD_KDE_plus="$2"; BUILD_XFCE_plus="$2"; shift 2 ;;
    -P) PulseAudio="$2"; shift 2 ;;
    -g) ENABLE_zh_tz="$2"; shift 2 ;;
    -a) ENABLE_binfmt="$2"; shift 2 ;;
    -b) ENABLE_yj="$2"; shift 2 ;;
    -c) ENABLE_mesa="$2"; shift 2 ;;
    -d) ENABLE_kfgj="$2"; shift 2 ;;
    -e) ENABLE_zip="$2"; shift 2 ;;
    -f) ENABLE_docker="$2"; shift 2 ;;
    -h) ENABLE_srf="$2"; shift 2 ;;
    -j) ENABLE_tmoe="$2"; shift 2 ;;
    -n) ENABLE_nosnap="$2"; shift 2 ;;
    -u) USERNAME="$2"; shift 2 ;;
    -*) echo "Unknown option: $1"; usage ;;
    *) echo "Unexpected argument: $1"; usage ;;
  esac
done

if [ -z "$DOCKERFILE" ]; then
  echo "Error: Dockerfile must be specified with -i."
  usage
fi

if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: template '$DOCKERFILE' not found."
  exit 1
fi

PREFIX=${DOCKERFILE%.Dockerfile}

echo "========================================================="
echo " Building: $PREFIX"
echo " Dockerfile: $DOCKERFILE"
echo " Version: $VERSION"
echo " Desktop(KDE/XFCE): ${BUILD_KDE:-none} / plus=${BUILD_KDE_plus}"
echo " PulseAudio: ${PulseAudio:-none}"
echo " binfmt: $ENABLE_binfmt"
echo " yj: ${ENABLE_yj:-}"
echo " nosnap: $ENABLE_nosnap"
echo "========================================================="

if ! docker buildx inspect droidspaces-builder >/dev/null 2>&1; then
  echo "Creating buildx builder: droidspaces-builder"
  docker buildx create --name droidspaces-builder --driver docker-container --use
else
  echo "Using existing buildx builder: droidspaces-builder"
  docker buildx use droidspaces-builder
fi

docker buildx inspect --bootstrap || echo "Warning: bootstrap failed, continuing..."

TEMP_TAR="custom-${PREFIX}-rootfs.tar"
FINAL_NAME="${PREFIX}-Droidspaces-rootfs-${ARCH}-${DATE}-${VERSION}.tar.xz"

echo "Running docker buildx build..."

docker buildx build \
  --target export \
  --output type=tar,dest="$TEMP_TAR" \
  --build-arg BUILD_KDE="$BUILD_KDE" \
  --build-arg BUILD_KDE_plus="$BUILD_KDE_plus" \
  --build-arg BUILD_XFCE="$BUILD_XFCE" \
  --build-arg BUILD_XFCE_plus="$BUILD_XFCE_plus" \
  --build-arg PulseAudio="$PulseAudio" \
  --build-arg ENABLE_zh_tz_ARG="$ENABLE_zh_tz" \
  --build-arg ENABLE_binfmt_ARG="$ENABLE_binfmt" \
  --build-arg ENABLE_yj_ARG="$ENABLE_yj" \
  --build-arg ENABLE_mesa_ARG="$ENABLE_mesa" \
  --build-arg ENABLE_kfgj_ARG="$ENABLE_kfgj" \
  --build-arg ENABLE_zip_ARG="$ENABLE_zip" \
  --build-arg ENABLE_docker_ARG="$ENABLE_docker" \
  --build-arg ENABLE_srf_ARG="$ENABLE_srf" \
  --build-arg ENABLE_tmoe_ARG="$ENABLE_tmoe" \
  --build-arg ENABLE_nosnap_ARG="$ENABLE_nosnap" \
  --build-arg USERNAME="$USERNAME" \
  -f "$DOCKERFILE" \
  .

echo "Compressing with xz..."
xz -T0 -9 -f "$TEMP_TAR"
mv "${TEMP_TAR}.xz" "$FINAL_NAME"

echo "========================================================="
echo " Done: $FINAL_NAME"
echo "========================================================="
