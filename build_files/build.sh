#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
# (flatpak manifest override, custom ujust recipes, sigstore config)
cp -avf "/ctx/system_files"/. /

### Extra packages

# LACT - GPU control daemon (COPR ilyaz/LACT)
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install lact
dnf5 -y copr disable ilyaz/LACT
systemctl enable lactd

### GNOME extensions baked system-wide from extensions.gnome.org releases
/ctx/install-gnome-extensions.sh

### Register custom ujust recipes
echo "import \"/usr/share/ublue-os/just/61-bazzite-jmc.just\"" >> /usr/share/ublue-os/justfile

### Sigstore policy for signed updates of this image.
# Requires the public cosign key committed at
# system_files/etc/pki/containers/bazzite-jmc.pub - skipped gracefully when absent,
# in which case only ostree-unverified-registry rebases work.
PUBKEY=/etc/pki/containers/bazzite-jmc.pub
if [[ -f "$PUBKEY" ]]; then
    jq --arg key "$PUBKEY" \
        '.transports.docker["ghcr.io/jmcjm/bazzite-jmc"] = [{"type":"sigstoreSigned","keyPath":$key,"signedIdentity":{"type":"matchRepository"}}]' \
        /etc/containers/policy.json > /tmp/policy.json
    cp /tmp/policy.json /etc/containers/policy.json
fi
