image_name := env("BUILD_IMAGE_NAME", "system")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "btrfs")
variant := env("BUILD_VARIANT", "composefs-sealeduki")

build-containerfile $image_name=image_name $variant=variant:
    #!/usr/bin/env bash
    set -euo pipefail

    sudo podman build -t "localhost/${image_name}:base" .
    # TODO: we can make this a CLI program with better UX: https://github.com/bootc-dev/bootc/issues/1498
    sudo ./build-sealed "${variant}" "localhost/${image_name}:base" "localhost/${image_name}:latest"


    # graphroot=$(sudo podman system info -f '{\{.Store.GraphRoot}}')
    # echo "Computing composefs digest..."
    # cfs_digest=$(sudo podman run --rm --privileged --read-only --security-opt=label=disable -v /sys:/sys:ro --net=none \
    #   -v ${graphroot}:/run/host-container-storage:ro --tmpfs /var "${image_name}:base" bootc container compute-composefs-digest)

    # # UKI step:
    # sudo podman build                                \
    #     --build-arg=base="${image_name}:base"        \
    #     --build-arg=COMPOSEFS_FSVERITY="$cfg_digest" \
    #     -t "${image_name}:${image_tag}"              \
    #     -f Containerfile.cfsuki .                    \

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    just bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd
