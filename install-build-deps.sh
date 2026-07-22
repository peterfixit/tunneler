#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -r /etc/os-release ]]; then
  echo "ERROR: /etc/os-release is unavailable." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
DISTRO_ID="${ID,,}"
DISTRO_LIKE=" ${ID_LIKE:-} "

if [[ "$DISTRO_ID" =~ ^(arch|cachyos|manjaro|endeavouros|garuda)$ ]] || [[ "$DISTRO_LIKE" == *" arch "* ]]; then
  sudo pacman -S --needed python python-pip tk curl base-devel
elif [[ "$DISTRO_ID" =~ ^(fedora|nobara)$ ]] || [[ "$DISTRO_LIKE" == *" fedora "* ]]; then
  sudo dnf install -y python3 python3-pip python3-tkinter curl gcc binutils
elif [[ "$DISTRO_ID" =~ ^(debian|ubuntu|kubuntu|linuxmint|pop)$ ]] || [[ "$DISTRO_LIKE" == *" debian "* ]]; then
  sudo apt-get update
  sudo apt-get install -y python3 python3-venv python3-pip python3-tk curl file
elif [[ "$DISTRO_ID" == opensuse* ]] || [[ "$DISTRO_LIKE" == *" suse "* ]]; then
  sudo zypper --non-interactive install python3 python3-pip python3-tk curl gcc
else
  echo "ERROR: Automatic build dependency installation is not available for ${PRETTY_NAME:-this distribution}." >&2
  echo "Install Python 3 with Tk, venv/pip, curl, and a C toolchain manually." >&2
  exit 1
fi

echo "Tunneler build dependencies are installed. These are not needed to run the finished AppImage."
