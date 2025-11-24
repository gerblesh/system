image_name := env("BUILD_IMAGE_NAME", "system")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", "/tmp")

filesystem := env("BUILD_FILESYSTEM", "btrfs")
variant := env("BUILD_VARIANT", "composefs-sealeduki")

namespace := env("BUILD_NAMESPACE", "gerblesh")
sudo := env("BUILD_ELEVATE", "sudo")
just_exe := just_executable()

enroll-secboot-key:
    #!/usr/bin/bash
    ENROLLMENT_PASSWORD=""
    SECUREBOOT_KEY=keys/db.cer
    "{{sudo}}" mokutil --timeout -1
    echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | "{{sudo}}" mokutil --import "$SECUREBOOT_KEY"
    echo 'At next reboot, the mokutil UEFI menu UI will be displayed (*QWERTY* keyboard input and navigation).\nThen, select "Enroll MOK", and input "bootcrew" as the password'

gen-secboot-keys:
    #!/usr/bin/env bash
    set -xeuo pipefail

    # for signing
    openssl req -quiet -newkey rsa:4096 -nodes -keyout keys/db.key -new -x509 -sha256 -days 3650 -subj '/CN=Test Signature Database key/' -out keys/db.crt
    openssl x509 -outform DER -in keys/db.crt -out keys/db.cer

    # test keys for VMs, etc
    openssl req -quiet -newkey rsa:4096 -nodes -keyout keys/KEK.key -new -x509 -sha256 -days 3650 -subj '/CN=Test Key Exchange Key/' -out keys/KEK.crt
    openssl x509 -outform DER -in keys/KEK.crt -out keys/KEK.cer

    openssl req -quiet -newkey rsa:4096 -nodes -keyout keys/PK.key -new -x509 -sha256 -days 3650 -subj '/CN=Test Platform Key/' -out keys/PK.crt
    openssl x509 -outform DER -in keys/PK.crt -out keys/PK.cer


build-containerfile $image_name=image_name $variant=variant:
    #!/usr/bin/env bash
    set -xeuo pipefail

    podman build -t "localhost/${image_name}_unsealed" .
    # TODO: we can make this a CLI program with better UX: https://github.com/bootc-dev/bootc/issues/1498
    ./build-sealed "${variant}" "localhost/${image_name}_unsealed" "${image_name}" "keys"


bootc *ARGS:
    {{sudo}} podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "localhost/{{image_name}}:{{image_tag}}" bootc {{ARGS}}

install-image $target_device $filesystem=filesystem:
    #!/usr/bin/env bash
    set -xeuo pipefail
    {{just_exe}} bootc install to-disk --composefs-backend --filesystem "${filesystem}" --wipe --bootloader systemd {{target_device}}

copy-image-root:
    podman save {{image_name}} | sudo podman load

pull-image-root:
    {{sudo}} podman pull ghcr.io/{{namespace}}/{{image_name}}:{{image_tag}}
    {{sudo}} podman tag "ghcr.io/{{namespace}}/{{image_name}}:{{image_tag}}" "localhost/{{image_name}}:{{image_tag}}"

fix-var-containers-selinux:
     {{sudo}} restorecon -RFv /var/lib/containers/storage

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    just bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd
