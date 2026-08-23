# Build context: scripts and files referenced during build without landing in the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base image: official bazzite-dx GNOME build (AMD/Intel variant).
# Intentionally an unpinned tag - the nightly scheduled build always picks up
# the current upstream base. If upstream breaks, our build fails loudly in CI
# and the machine simply stays on the last good image.
FROM ghcr.io/ublue-os/bazzite-dx-gnome:stable

### MODIFICATIONS
## All customization happens in build_files/build.sh - packages previously
## carried as client-side rpm-ostree layers, GNOME extensions baked system-wide,
## the flatpak manifest override and custom ujust recipes.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
