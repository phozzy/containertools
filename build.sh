#!/usr/bin/env bash
export $(podman --cgroup-manager=cgroupfs run --systemd=false registry.fedoraproject.org/fedora grep VERSION_ID /etc/os-release)
echo ${VERSION_ID}
