#!/usr/bin/env bash
set -euo pipefail

dnf install -y dnf-plugins-core

if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

dnf makecache
dnf install -y containerd.io

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd
