#!/usr/bin/env bash
set -euo pipefail

NODE_HOSTS="${1:-}"

swapoff -a || true
sed -i '/swap/d' /etc/fstab

cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

systemctl disable --now firewalld || true

dnf install -y iscsi-initiator-utils nfs-utils
systemctl enable --now iscsid

if [[ -n "${NODE_HOSTS}" ]]; then
  cp /etc/hosts /etc/hosts.bak.k8s-bootstrap
  awk '!/ kube$| kube02$| kube03$| kube04$/' /etc/hosts.bak.k8s-bootstrap >/etc/hosts

  IFS=',' read -r -a entries <<< "${NODE_HOSTS}"
  for entry in "${entries[@]}"; do
    ip="${entry%%:*}"
    name="${entry##*:}"
    printf '%s   %s\n' "${ip}" "${name}" >>/etc/hosts
  done
fi
