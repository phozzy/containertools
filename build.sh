#!/usr/bin/env bash
export $(podman run registry.fedoraproject.org/fedora grep VERSION_ID /etc/os-release)
echo ${VERSION_ID}
