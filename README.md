# bazzite-jmc

Personal bootc image: `ghcr.io/ublue-os/bazzite-dx-gnome:stable` plus a thin
customization layer. Scaffolding comes from
[ublue-os/image-template](https://github.com/ublue-os/image-template)
(Justfile, workflow, rechunking and signing left untouched).

The heavy lifting (gaming kernel, Valve-patched Mesa, gamescope, native Steam,
the whole DX toolchain) is inherited from the upstream base image — this repo
only carries the delta.

## What the delta adds

| Item | Where |
|---|---|
| LACT (COPR `ilyaz/LACT`) with `lactd` enabled | `build_files/build.sh` |
| 14 GNOME extensions baked system-wide, fetched from extensions.gnome.org for the Shell version of the image | `build_files/install-gnome-extensions.sh` |
| Trimmed flatpak manifest (daily drivers + adw-gtk3 themes; no Steam/Lutris — those are native in the base) | `system_files/etc/ublue-os/system_flatpaks` |
| A hook that actually installs the flatpak manifest — upstream bazzite-dx ships its list without any consumer (orphan left over from the amyOS rebranding) | `system_files/usr/share/ublue-os/system-setup.hooks.d/30-system-flatpaks.sh` |
| `ujust toggle-gamemode-gdm` — working replacement for the upstream toggle, which writes SDDM config that GDM (used by the GNOME variant) never reads | `system_files/usr/share/ublue-os/just/61-bazzite-jmc.just` |
| Sigstore policy for signed updates of this image | `build_files/build.sh` + `system_files/etc/containers/registries.d/` |

Extension updates ride the scheduled image builds — do not click "update" in
Extension Manager, as that creates a shadowing copy in `~/.local`.

## Building locally

```bash
just build bazzite-jmc latest
```

## Rebasing to this image

```bash
# first rebase, unverified
rpm-ostree rebase ostree-unverified-registry:ghcr.io/jmcjm/bazzite-jmc:latest
systemctl reboot

# after the first boot, switch to the signed variant
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/jmcjm/bazzite-jmc:latest
```

**Do not rebase between GNOME and KDE variants** — upstream bazzite-dx warning;
it can break the installation beyond repair.

## Signing

Images are signed with cosign. One-time setup after cloning:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

- `cosign.key` → GitHub repository secret `SIGNING_SECRET` (never commit it)
- `cosign.pub` → committed in the repo root **and** copied to
  `system_files/etc/pki/containers/bazzite-jmc.pub` (without it the build skips
  the sigstore policy and only unverified rebases work)

## Notes

- `/etc/bazzite/image_name` in the base still contains the deck image name, so
  `ujust setup-sunshine` takes the deck path (Sunshine via brew + KMS capture).
- The `system_flatpaks` manifest is additive — the hook installs missing
  entries (once per list change, guarded by a sha256 stamp) and never removes
  anything. Comments and empty lines are allowed.
- Vulkan layer flatpaks (MangoHud, vkBasalt) are intentionally absent from the
  manifest: native Steam uses the native MangoHud from the base image, and the
  flatpak layer can be installed on demand with the branch matching the app
  runtime that needs it.
