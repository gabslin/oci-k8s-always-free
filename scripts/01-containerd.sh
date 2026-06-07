#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib-packages.sh"

dnf_retry install -y dnf-plugins-core

rm -f /etc/yum.repos.d/docker-ce.repo
dnf config-manager --add-repo https://download.docker.com/linux/oracle/docker-ce.repo

rpm_import_retry https://download.docker.com/linux/oracle/gpg
dnf_retry makecache
dnf_retry install -y containerd.io

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd
