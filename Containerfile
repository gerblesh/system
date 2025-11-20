FROM docker.io/archlinux/archlinux:latest

# base deps
RUN --mount=type=tmpfs,dst=/tmp --mount=type=cache,dst=/var/log --mount=type=cache,dst=/var/cache \
    pacman -Sy --noconfirm \
      base \
      dracut \
      linux \
      linux-firmware \
      ostree \
      btrfs-progs \
      e2fsprogs \
      xfsprogs \
      dosfstools \
      skopeo \
      dbus \
      dbus-glib \
      glib2 \
      ostree \
      shadow && \
  pacman -S --clean --noconfirm

# Regression with newer dracut broke this
RUN mkdir -p /etc/dracut.conf.d && \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /etc/dracut.conf.d/fix-bootc.conf

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=cache,dst=/var/cache --mount=type=cache,dst=/var/log \
    pacman -S --noconfirm base-devel git rust && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    make -C /tmp/bootc bin install-all && \
    sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"' && \
    pacman -Rns --noconfirm base-devel git rust && \
    pacman -S --clean --noconfirm

# Necessary for general behavior expected by image-based systems
RUN --mount=type=tmpfs,dst=/tmp --mount=type=cache,dst=/var/log --mount=type=cache,dst=/var/cache \
    sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"  && \
    rm -rf /boot /home /root /usr/local /srv                    && \
    mkdir -p /var /sysroot /boot /usr/lib/ostree /usr/share/db  && \
    ln -s var/opt /opt                                          && \
    ln -s var/roothome /root                                    && \
    ln -s var/home /home                                        && \
    ln -s sysroot/ostree /ostree                                && \
    mv /var/lib/pacman  /usr/share/db/pacman                    && \
    mv /var/db/Makefile  /usr/share/db/Makefile                 && \
    ln -s /usr/share/db/pacman /var/lib/pacman                  && \
    echo "$(for dir in opt usrlocal home srv mnt db; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /var/roothome 0700 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /run/media 0755 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "L /var/lib/pacman - root root - /usr/share/db/pacman" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "L /var/db/Makefile - - - - /usr/share/db/Makefile" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "L /var/mail - - - - /var/spool/mail" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    printf "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | tee "/usr/lib/ostree/prepare-root.conf"


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
        helvum                        \
        wezterm                       \
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
        flatpak                    && \
    pacman -S --clean --noconfirm

# Setup a temporary root passwd (changeme) for dev purposes
# RUN pacman -Sy --clean --noconfirm pac && \
#     rm -rf /var/cache/pacman/pkg/*
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN rm -rf /var/cache/* /var/log/* && bootc container lint
LABEL containers.bootc=1
