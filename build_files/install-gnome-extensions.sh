#!/usr/bin/env bash
# Bake GNOME Shell extensions system-wide from extensions.gnome.org releases.
# Each build fetches the newest release matching the image's GNOME Shell major
# version, so extension updates ride the nightly image builds. The build fails
# loudly when an extension has no release for the current Shell version.

set -euo pipefail

EXTENSIONS=(
    "appindicatorsupport@rgcjonas.gmail.com"
    "ascii-emoji@masood.masaeli"
    "blur-my-shell@aunetx"
    "caffeine@patapon.info"
    "color-picker@tuberry"
    "dash-to-dock@micxgx.gmail.com"
    "emoji-copy@felipeftn"
    "gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com"
    "gsconnect@andyholmes.github.io"
    "just-perfection-desktop@just-perfection"
    "quick-settings-audio-panel@rayzeq.github.io"
    "quick-settings-tweaks@qwreey"
    "restartto@tiagoporsch.github.io"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

EXT_DIR=/usr/share/gnome-shell/extensions
EGO=https://extensions.gnome.org

command -v unzip >/dev/null || dnf5 -y install unzip

SHELL_MAJOR=$(rpm -q gnome-shell --qf '%{VERSION}' | cut -d. -f1)
echo "Baking ${#EXTENSIONS[@]} extensions for GNOME Shell ${SHELL_MAJOR}"

for uuid in "${EXTENSIONS[@]}"; do
    info=$(curl -sf --retry 3 "${EGO}/extension-info/?uuid=${uuid}&shell_version=${SHELL_MAJOR}")
    dl=$(jq -r '.download_url // empty' <<<"$info")
    if [[ -z "$dl" ]]; then
        echo "ERROR: ${uuid} has no release for GNOME Shell ${SHELL_MAJOR}" >&2
        exit 1
    fi

    tmp=$(mktemp)
    curl -sfL --retry 3 "${EGO}${dl}" -o "$tmp"

    # Overwrites extensions the base image also ships (caffeine, appindicator,
    # restartto) with the current upstream release - intentional.
    rm -rf "${EXT_DIR:?}/${uuid}"
    install -d -m 0755 "${EXT_DIR}/${uuid}"
    unzip -oq "$tmp" -d "${EXT_DIR}/${uuid}"
    rm -f "$tmp"

    find "${EXT_DIR}/${uuid}" -type d -exec chmod 0755 {} +
    find "${EXT_DIR}/${uuid}" -type f -exec chmod 0644 {} +

    if [[ -d "${EXT_DIR}/${uuid}/schemas" ]]; then
        glib-compile-schemas --strict "${EXT_DIR}/${uuid}/schemas"
    fi

    echo "Installed ${uuid}"
done
