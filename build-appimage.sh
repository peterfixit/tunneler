#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-appimage"
APPDIR="$BUILD_DIR/Tunneler.AppDir"
DIST_DIR="$ROOT_DIR/dist"
VERSION="1.1.0"
ARCH="${ARCH:-$(uname -m)}"
PYINSTALLER_VERSION="6.16.0"
PYTHON_PREFIX="$(python3 -c 'import sys; print(sys.prefix)')"
VENV_LD_LIBRARY_PATH="$PYTHON_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
VENV_DIR="${TUNNELER_BUILD_VENV:-${TUNNY_BUILD_VENV:-${TMPDIR:-/tmp}/tunneler-appimage-$VERSION-$ARCH-venv}}"

case "$ARCH" in
  x86_64|aarch64) ;;
  *)
    echo "ERROR: Tunneler AppImage builds currently support x86_64 and aarch64." >&2
    exit 1
    ;;
esac

for command in python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: $command is required. Run packaging/install-build-deps.sh." >&2
    exit 1
  fi
done

if ! python3 -c 'import tkinter' >/dev/null 2>&1; then
  echo "ERROR: Python Tk support is required. Run packaging/install-build-deps.sh." >&2
  exit 1
fi

rm -rf -- "$APPDIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR" "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps" \
  "$APPDIR/usr/share/metainfo"

venv_python() {
  env LD_LIBRARY_PATH="$VENV_LD_LIBRARY_PATH" "$VENV_DIR/bin/python" "$@"
}

if [[ -z "${PYINSTALLER_PYTHONPATH:-}" ]]; then
  if [[ ! -x "$VENV_DIR/bin/python" ]] || \
     ! venv_python -c 'import tkinter' >/dev/null 2>&1; then
    # A moved/extracted source tree can retain unusable absolute venv symlinks.
    rm -rf -- "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
    if ! venv_python -c 'import tkinter' >/dev/null 2>&1; then
      echo "ERROR: The build virtual environment cannot load Python Tk support." >&2
      exit 1
    fi
  fi
  venv_python -m pip install --disable-pip-version-check --upgrade pip
  venv_python -m pip install \
    --disable-pip-version-check --only-binary=:all: "pyinstaller==$PYINSTALLER_VERSION"
fi

run_pyinstaller() {
  if [[ -n "${PYINSTALLER_PYTHONPATH:-}" ]]; then
    PYTHONPATH="$PYINSTALLER_PYTHONPATH" python3 -m PyInstaller "$@"
  else
    venv_python -m PyInstaller "$@"
  fi
}

rm -rf -- "$BUILD_DIR/pyinstaller" "$BUILD_DIR/tunneler" "$BUILD_DIR/tunneler.spec"
cd "$ROOT_DIR"
EXTRA_PYINSTALLER_ARGS=()
for library in libtcl9.0.so libtcl9tk9.0.so; do
  if [[ -f "$PYTHON_PREFIX/lib/$library" ]]; then
    EXTRA_PYINSTALLER_ARGS+=(--add-binary "$PYTHON_PREFIX/lib/$library:.")
  fi
done
run_pyinstaller \
  --noconfirm \
  --clean \
  --onedir \
  --windowed \
  --name tunneler \
  --distpath "$BUILD_DIR/pyinstaller" \
  --workpath "$BUILD_DIR/pyinstaller-work" \
  --specpath "$BUILD_DIR" \
  --add-data "$ROOT_DIR/assets:assets" \
  "${EXTRA_PYINSTALLER_ARGS[@]}" \
  app.py

cp -a "$BUILD_DIR/pyinstaller/tunneler/." "$APPDIR/usr/bin/"
if ! compgen -G "$APPDIR/usr/bin/_internal/python*/lib-dynload/_tkinter*.so" >/dev/null || \
   ! compgen -G "$APPDIR/usr/bin/_internal/libtcl*.so*" >/dev/null || \
   ! compgen -G "$APPDIR/usr/bin/_internal/lib*t*k*.so*" >/dev/null || \
   [[ ! -d "$APPDIR/usr/bin/_internal/_tcl_data" ]] || \
   [[ ! -d "$APPDIR/usr/bin/_internal/_tk_data" ]]; then
  echo "ERROR: The bundled Python/Tcl/Tk runtime is incomplete." >&2
  exit 1
fi
cp "$ROOT_DIR/au.pmhs.tunneler.desktop" "$APPDIR/au.pmhs.tunneler.desktop"
cp "$ROOT_DIR/au.pmhs.tunneler.desktop" "$APPDIR/usr/share/applications/au.pmhs.tunneler.desktop"
cp "$ROOT_DIR/assets/au.pmhs.tunneler.svg" "$APPDIR/au.pmhs.tunneler.svg"
cp "$ROOT_DIR/assets/au.pmhs.tunneler.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/au.pmhs.tunneler.svg"
cp "$ROOT_DIR/packaging/au.pmhs.tunneler.metainfo.xml" "$APPDIR/usr/share/metainfo/au.pmhs.tunneler.metainfo.xml"
cp "$ROOT_DIR/packaging/au.pmhs.tunneler.metainfo.xml" "$APPDIR/usr/share/metainfo/au.pmhs.tunneler.appdata.xml"
ln -sfn au.pmhs.tunneler.svg "$APPDIR/.DirIcon"

cat >"$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/usr/bin/tunneler" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun" "$APPDIR/usr/bin/tunneler"

APPIMAGETOOL="${APPIMAGETOOL:-}"
if [[ -z "$APPIMAGETOOL" ]] && command -v appimagetool >/dev/null 2>&1; then
  APPIMAGETOOL="$(command -v appimagetool)"
fi
if [[ -z "$APPIMAGETOOL" ]]; then
  APPIMAGETOOL="$BUILD_DIR/appimagetool-$ARCH.AppImage"
  if [[ ! -x "$APPIMAGETOOL" ]]; then
    if [[ "${NO_DOWNLOAD:-0}" == "1" ]]; then
      echo "ERROR: appimagetool is unavailable and NO_DOWNLOAD=1." >&2
      exit 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
      echo "ERROR: curl is required to download appimagetool." >&2
      exit 1
    fi
    URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
    echo "Downloading appimagetool from the official AppImage release…"
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 \
      --output "$APPIMAGETOOL.part" "$URL"
    mv "$APPIMAGETOOL.part" "$APPIMAGETOOL"
    chmod 0755 "$APPIMAGETOOL"
  fi
fi

OUTPUT="$DIST_DIR/Tunneler-$VERSION-$ARCH.AppImage"
rm -f -- "$OUTPUT"
export ARCH VERSION
if "$APPIMAGETOOL" --version >/dev/null 2>&1; then
  "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
else
  "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"
fi
chmod 0755 "$OUTPUT"

# A stock type-2 runtime mounts through FUSE before AppRun starts. Tunneler
# deliberately defaults the same runtime to its official extract-and-run path,
# keeping the download usable on systems without libfuse2. The runtime enables
# that path when its environment-key lookup exists; PATH is present in normal
# desktop and terminal launches. The replacement is equal-length and the build
# fails if an updated runtime no longer has exactly one expected marker.
python3 - "$OUTPUT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = bytearray(path.read_bytes())
needle = b"APPIMAGE_EXTRACT_AND_RUN\0"
replacement = b"PATH\0" + (b"\0" * (len(needle) - 5))
count = data.count(needle)
if count != 1:
    raise SystemExit(f"ERROR: Expected one AppImage extract-and-run marker, found {count}.")
offset = data.index(needle)
data[offset : offset + len(needle)] = replacement
path.write_bytes(data)
PY
chmod 0755 "$OUTPUT"

if ! env -u APPIMAGE_EXTRACT_AND_RUN "$OUTPUT" --version; then
  echo "ERROR: The built AppImage failed its launch smoke test." >&2
  exit 1
fi

(cd "$DIST_DIR" && sha256sum "$(basename -- "$OUTPUT")" >"$(basename -- "$OUTPUT").sha256")
echo "Built: $OUTPUT"
du -h "$OUTPUT"
