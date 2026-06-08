#!/usr/bin/env bash
set -euo pipefail

CONTROL_PLANE_PRIVATE_IP="${1:?IP privado do control-plane nao informado}"
CONTROL_PLANE_PUBLIC_IP="${2:?IP publico do control-plane nao informado}"

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  kubeadm init \
    --apiserver-advertise-address="${CONTROL_PLANE_PRIVATE_IP}" \
    --apiserver-cert-extra-sans="${CONTROL_PLANE_PUBLIC_IP}" \
    --pod-network-cidr=10.244.0.0/16 \
    --ignore-preflight-errors=NumCPU
fi

mkdir -p /home/opc/.kube
cp /etc/kubernetes/admin.conf /home/opc/.kube/config
chown -R opc:opc /home/opc/.kube

export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

kubeadm token create --print-join-command >/root/kubeadm_join.sh
chmod 600 /root/kubeadm_join.sh
