FROM docker.io/archlinux/archlinux:latest

# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

RUN pacman -Sy --noconfirm base dracut linux linux-firmware ostree btrfs-progs e2fsprogs xfsprogs dosfstools skopeo dbus dbus-glib glib2 ostree shadow fwupd sbctl tpm2-tss tpm2-pkcs11 && pacman -S --clean --noconfirm

# https://github.com/bootc-dev/bootc/issues/1801
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm make git rust && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    make -C /tmp/bootc bin install-all && \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" ostree bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    printf 'add_dracutmodules+=" fido2 tpm2-tss pkcs11 systemd-pcrphase "\n' | tee "/usr/lib/dracut/dracut.conf.d/20-bootcrew-tpm-luks.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img" && \
    pacman -Rns --noconfirm make git rust && \
    pacman -S --clean --noconfirm

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

# sway + custom shit
RUN --mount=type=tmpfs,dst=/tmp --mount=type=cache,dst=/var/log --mount=type=cache,dst=/var/cache \
    pacman -Sy --noconfirm            \
        sway                          \
        swayidle                      \
        swaybg                        \
        grim                          \
        slurp                         \
        brightnessctl                 \
        wtype                         \
        wf-recorder                   \
        sway-contrib                  \
        swaylock                      \
        swayimg                       \
        waybar                        \
        mako                          \
        seatd                         \
        system-config-printer         \
        blueman                       \
        chezmoi                       \
        git                           \
        gnome-disk-utility            \
        gcc                           \
        network-manager-applet        \
        ghostty                       \
        ghostty-terminfo              \
        ghostty-shell-integration     \
        fish                          \
        ghostty-terminfo              \
        ibus                          \
        thunar                        \
        xarchiver                     \
        thunar-archive-plugin         \
        thunar-media-tags-plugin      \
        thunar-shares-plugin          \
        pipewire-jack                 \
        pipewire-alsa                 \
        wireplumber                   \
        zathura                       \
        lxqt-policykit                \
        gvfs                          \
        gvfs-onedrive                 \
        gvfs-mtp                      \
        podman                        \
        podman-compose                \
        distrobox                     \
        cliphist                      \
        rofi                          \
        xdg-desktop-portal-wlr        \
        android-tools                 \
        android-udev                  \
        android-file-transfer         \
        tuned                         \
        tuned-ppd                     \ 
        tailscale                     \
        ufw                           \
        xdg-desktop-portal-gtk        \
        xdg-user-dirs-gtk             \
        ttf-jetbrains-mono-nerd       \
        ttf-nerd-fonts-symbols-mono   \
        ttf-nerd-fonts-symbols-common \
        ttf-ibm-plex                  \
        ttf-roboto                    \
        gsfonts                       \
        ttf-liberation                \
        noto-fonts                    \
        ttf-dejavu                    \
        noto-fonts-emoji              \
        noto-fonts-extra              \
        noto-fonts-cjk                \
        pcre2                         \
        less                          \
        vim                           \
        sbctl                         \
        flatpak                    && \
    pacman -S --clean --noconfirm


RUN pacman -S whois --noconfirm
RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN bootc container lint
LABEL containers.bootc=1
