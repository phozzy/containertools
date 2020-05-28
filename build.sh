#!/usr/bin/env bash
podman pull registry.fedoraproject.org/fedora:latest
export $(podman run registry.fedoraproject.org/fedora grep VERSION_ID /etc/os-release)
echo ${VERSION_ID}
NEWCONTAINER=$(buildah from scratch)
echo ${NEWCONTAINER}
SCRATCHMNT=$(buildah mount ${NEWCONTAINER})
echo ${SCRATCHMNT}
podman run -v ${SCRATCHMNT}:/mnt:rw registry.fedoraproject.org/fedora bash -c "dnf install --installroot /mnt bash coreutils shadow-utils fuse-overlayfs buildah podman skopeo --exclude container-selinux --releasever ${VERSION_ID} --setopt=tsflags=nodocs --setopt=install_weak_deps=False --setopt=override_install_langs=en_US.utf8 -y && dnf clean all"
buildah run ${NEWCONTAINER} useradd build
if [ -d ${SCRATCHMNT} ]; then rm -rf ${SCRATCHMNT}/var/cache ${SCRATCHMNT}/var/log/dnf* ${SCRATCHMNT}/var/log/yum.*; fi
cp containers.conf ${SCRATCHMNT}/etc/containers/
chmod 644 ${SCRATCHMNT}/etc/containers/containers.conf
if [ -f ${SCRATCHMNT}/etc/containers/storage.conf ]; then sed -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' -i ${SCRATCHMNT}/etc/containers/storage.conf; fi
mkdir -p ${SCRATCHMNT}/var/lib/shared/overlay-images ${SCRATCHMNT}/var/lib/shared/overlay-layers
touch ${SCRATCHMNT}/var/lib/shared/overlay-images/images.lock
touch ${SCRATCHMNT}/var/lib/shared/overlay-layers/layers.lock
echo build:100000:65536 > ${SCRATCHMNT}/etc/subuid
echo build:100000:65536 > ${SCRATCHMNT}/etc/subgid
buildah config --env _CONTAINERS_USERNS_CONFIGURED="" ${NEWCONTAINER}
buildah config --env BUILDAH_ISOLATION=chroot ${NEWCONTAINER}
buildah config --env REGISTRY_AUTH_FILE=/auth.json ${NEWCONTAINER}
buildah config --user build ${NEWCONTAINER}
buildah config --workingdir /home/build ${NEWCONTAINER}
buildah config --cmd /bin/bash ${NEWCONTAINER}
buildah config --label name=containertools ${NEWCONTAINER}
buildah unmount ${NEWCONTAINER}
buildah commit ${NEWCONTAINER} containertools
echo "Test the image"
podman run containertools bash -c "id && pwd && buildah --version && podman --version && skopeo --version || exit" || exit
echo "Login to Github packages"
echo $GITHUB_TOKEN | buildah login -u $GITHUB_ACTOR --password-stdin https://docker.pkg.github.com
echo "Publish images"
buildah tag containertools docker.pkg.github.com/${GITHUB_REPOSITORY}/containertools:latest
buildah tag containertools docker.pkg.github.com/${GITHUB_REPOSITORY}/containertools:${VERSION_ID}
buildah push docker.pkg.github.com/${GITHUB_REPOSITORY}/containertools:latest
buildah push docker.pkg.github.com/${GITHUB_REPOSITORY}/containertools:${VERSION_ID}
