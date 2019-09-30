#!/usr/bin/env bash
export CI_PROJECT_NAME=containertools
export CI_REGISTRY_IMAGE="docker.pkg.github.com/phozzy/containertools/containertools"
export CI_REGISTRY_USER=phozzy
export $(podman --cgroup-manager=cgroupfs run --systemd=false registry.fedoraproject.org/fedora grep VERSION_ID /etc/os-release)
NEWCONTAINER=$(buildah from scratch)
SCRATCHMNT=$(buildah mount ${NEWCONTAINER})
podman --cgroup-manager=cgroupfs run -v ${SCRATCHMNT}:/mnt:rw --systemd=false registry.fedoraproject.org/fedora bash -c "dnf install --installroot /mnt bash coreutils fuse-overlayfs buildah podman skopeo --exclude container-selinux --releasever ${VERSION_ID} --setopt=tsflags=nodocs --setopt=install_weak_deps=False --setopt=override_install_langs=en_US.utf8 -y && dnf clean all"
if [ -d ${SCRATCHMNT} ]; then rm -rf ${SCRATCHMNT}/var/cache/dnf; fi
if [ -f ${SCRATCHMNT}/etc/containers/storage.conf ]; then sed -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -i ${SCRATCHMNT}/etc/containers/storage.conf; fi
mkdir -p ${SCRATCHMNT}/var/lib/shared/overlay-images ${SCRATCHMNT}/var/lib/shared/overlay-layers
touch ${SCRATCHMNT}/var/lib/shared/overlay-images/images.lock
touch ${SCRATCHMNT}/var/lib/shared/overlay-layers/layers.lock
if [ -f ${SCRATCHMNT}/usr/share/containers/libpod.conf ]; then sed -i 's/\#\ events_logger = "journald"/events_logger = "file"/g' ${SCRATCHMNT}/usr/share/containers/libpod.conf; fi
buildah config --env _BUILDAH_STARTED_IN_USERNS="" ${NEWCONTAINER}
buildah config --env BUILDAH_ISOLATION=chroot ${NEWCONTAINER}
buildah config --label name=${CI_PROJECT_NAME} ${NEWCONTAINER}
buildah config --cmd /bin/bash ${NEWCONTAINER}
buildah unmount ${NEWCONTAINER}
buildah commit ${NEWCONTAINER} ${CI_PROJECT_NAME}
buildah tag ${CI_PROJECT_NAME} ${CI_REGISTRY_IMAGE}:latest
buildah tag ${CI_PROJECT_NAME} ${CI_REGISTRY_IMAGE}:${VERSION_ID}
podman --cgroup-manager=cgroupfs run --systemd=false ${CI_REGISTRY_IMAGE}:${VERSION_ID} bash -c "buildah --version && podman --version && skopeo --version || exit" || exit
buildah push --creds ${CI_REGISTRY_USER}:${CI_JOB_TOKEN} ${CI_REGISTRY_IMAGE}:${VERSION_ID}
buildah push --creds ${CI_REGISTRY_USER}:${CI_JOB_TOKEN} ${CI_REGISTRY_IMAGE}:latest
