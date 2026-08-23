# vim: set ft=make :
#
# Custom recipes for the bazzite-jmc image.
#
# Upstream `ujust toggle-gamemode` writes /etc/sddm.conf.d/zz-steamos-autologin.conf,
# which GDM (used by the GNOME variant) never reads - the recipe is dead on
# bazzite-dx-gnome. This replacement drives GDM directly: the default session is
# set through AccountsService and autologin through /etc/gdm/custom.conf.
# Experimental - verify the first boot into Game Mode with physical access.

# Install Homebrew packages from the image's Brewfile
[group('apps')]
install-brews:
    #!/usr/bin/bash
    set -euo pipefail
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    brew bundle --file=/usr/share/ublue-os/homebrew/bazzite-jmc.Brewfile

# Toggle default boot between Steam Game Mode and GNOME desktop (GDM variant). Options: gamemode | desktop | status
[group('gaming')]
toggle-gamemode-gdm ACTION="":
    #!/usr/bin/bash
    set -euo pipefail
    ACTION="{{ ACTION }}"
    USERNAME=$(id -un)
    ASV_FILE="/var/lib/AccountsService/users/${USERNAME}"
    GDM_CONF="/etc/gdm/custom.conf"

    GAMESCOPE_DESKTOP=$(ls /usr/share/wayland-sessions/gamescope-session*.desktop 2>/dev/null | head -1 || true)
    if [[ -z "$GAMESCOPE_DESKTOP" ]]; then
        echo "No gamescope session found in /usr/share/wayland-sessions - nothing to toggle." >&2
        exit 1
    fi
    GAMESCOPE_SESSION=$(basename -s .desktop "$GAMESCOPE_DESKTOP")

    current_session="gnome"
    if [[ -f "$ASV_FILE" ]] && grep -q '^Session=' "$ASV_FILE"; then
        current_session=$(grep -Po '^Session=\K.*' "$ASV_FILE")
    fi

    set_session() {
        if [[ -f "$ASV_FILE" ]] && grep -q '^\[User\]' "$ASV_FILE"; then
            if grep -q '^Session=' "$ASV_FILE"; then
                sudo sed -i "s/^Session=.*/Session=$1/" "$ASV_FILE"
            else
                sudo sed -i "/^\[User\]/a Session=$1" "$ASV_FILE"
            fi
        else
            printf '[User]\nSession=%s\n' "$1" | sudo tee -a "$ASV_FILE" >/dev/null
        fi
    }

    strip_autologin() {
        sudo sed -i -e '/^AutomaticLoginEnable=/d' -e '/^AutomaticLogin=/d' "$GDM_CONF"
    }

    enable_autologin() {
        strip_autologin
        if ! grep -q '^\[daemon\]' "$GDM_CONF"; then
            printf '\n[daemon]\n' | sudo tee -a "$GDM_CONF" >/dev/null
        fi
        sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=True" "$GDM_CONF"
        sudo sed -i "/^AutomaticLoginEnable=True/a AutomaticLogin=${USERNAME}" "$GDM_CONF"
    }

    case "${ACTION,,}" in
        status|"")
            echo "Default session: ${current_session}"
            grep -E '^AutomaticLogin' "$GDM_CONF" 2>/dev/null || echo "Autologin: disabled"
            if [[ -z "$ACTION" ]]; then
                echo ""
                echo "Usage: ujust toggle-gamemode-gdm [gamemode|desktop|status]"
            fi
            ;;
        gamemode)
            set_session "$GAMESCOPE_SESSION"
            enable_autologin
            echo "Default boot set to Game Mode (${GAMESCOPE_SESSION}, autologin enabled)."
            echo "Reboot to apply."
            ;;
        desktop)
            set_session "gnome"
            strip_autologin
            echo "Default boot set to GNOME desktop (autologin disabled). Reboot to apply."
            ;;
        *)
            echo "Unrecognized action: ${ACTION}" >&2
            echo "Usage: ujust toggle-gamemode-gdm [gamemode|desktop|status]" >&2
            exit 1
            ;;
    esac
