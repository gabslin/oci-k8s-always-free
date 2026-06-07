#!/usr/bin/env bash
set -euo pipefail

JOIN_COMMAND="${1:?Comando kubeadm join nao informado}"

if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "Worker ja faz parte de um cluster. Pulando kubeadm join."
  exit 0
fi

eval "${JOIN_COMMAND}"
