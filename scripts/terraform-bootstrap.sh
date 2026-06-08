#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY nao definido}"
: "${CONTROL_PLANE_PUBLIC_IP:?CONTROL_PLANE_PUBLIC_IP nao definido}"
: "${CONTROL_PLANE_PRIVATE_IP:?CONTROL_PLANE_PRIVATE_IP nao definido}"
: "${WORKER_NAMES:?WORKER_NAMES nao definido}"
: "${WORKER_PUBLIC_IPS:?WORKER_PUBLIC_IPS nao definido}"
: "${NODE_HOSTS:?NODE_HOSTS nao definido}"
: "${METALLB_POOL:?METALLB_POOL nao definido}"

SSH_OPTS=(
  -i "${SSH_PRIVATE_KEY}"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ServerAliveInterval=60
  -o ServerAliveCountMax=10
)

read -r -a WORKER_NAME_ARRAY <<< "${WORKER_NAMES}"
read -r -a WORKER_IP_ARRAY <<< "${WORKER_PUBLIC_IPS}"

if [[ "${#WORKER_NAME_ARRAY[@]}" -ne "${#WORKER_IP_ARRAY[@]}" ]]; then
  echo "WORKER_NAMES e WORKER_PUBLIC_IPS precisam ter o mesmo tamanho." >&2
  exit 1
fi

wait_ssh() {
  local host="$1"
  local label="$2"

  echo "Aguardando SSH em ${label} (${host})..."
  for _ in {1..90}; do
    if ssh "${SSH_OPTS[@]}" "opc@${host}" "true" >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  echo "SSH nao ficou disponivel em ${label} (${host})." >&2
  exit 1
}

upload_bootstrap() {
  local host="$1"
  local label="$2"

  ssh "${SSH_OPTS[@]}" "opc@${host}" "mkdir -p /home/opc/k8s-bootstrap"
  scp "${SSH_OPTS[@]}" -r "${PROJECT_DIR}/scripts" "opc@${host}:/home/opc/k8s-bootstrap/"
  ssh "${SSH_OPTS[@]}" "opc@${host}" "chmod +x /home/opc/k8s-bootstrap/scripts/*.sh"
  echo "Bootstrap enviado para ${label}."
}

prepare_node() {
  local host="$1"
  local label="$2"

  echo "Preparando ${label}..."
  ssh "${SSH_OPTS[@]}" "opc@${host}" \
    "sudo cloud-init status --wait || true; sudo /home/opc/k8s-bootstrap/scripts/00-common.sh '${NODE_HOSTS}' && sudo /home/opc/k8s-bootstrap/scripts/01-containerd.sh && sudo /home/opc/k8s-bootstrap/scripts/02-kubernetes.sh"
}

wait_ssh "${CONTROL_PLANE_PUBLIC_IP}" "kube"
upload_bootstrap "${CONTROL_PLANE_PUBLIC_IP}" "kube"

for index in "${!WORKER_IP_ARRAY[@]}"; do
  wait_ssh "${WORKER_IP_ARRAY[$index]}" "${WORKER_NAME_ARRAY[$index]}"
  upload_bootstrap "${WORKER_IP_ARRAY[$index]}" "${WORKER_NAME_ARRAY[$index]}"
done

prepare_node "${CONTROL_PLANE_PUBLIC_IP}" "kube"

for index in "${!WORKER_IP_ARRAY[@]}"; do
  prepare_node "${WORKER_IP_ARRAY[$index]}" "${WORKER_NAME_ARRAY[$index]}"
done

echo "Inicializando control-plane..."
ssh "${SSH_OPTS[@]}" "opc@${CONTROL_PLANE_PUBLIC_IP}" \
  "sudo /home/opc/k8s-bootstrap/scripts/03-control-plane.sh '${CONTROL_PLANE_PRIVATE_IP}' '${CONTROL_PLANE_PUBLIC_IP}'"

JOIN_COMMAND="$(ssh "${SSH_OPTS[@]}" "opc@${CONTROL_PLANE_PUBLIC_IP}" "sudo cat /root/kubeadm_join.sh")"
JOIN_COMMAND_ESCAPED="$(printf '%q' "${JOIN_COMMAND}")"

for index in "${!WORKER_IP_ARRAY[@]}"; do
  echo "Adicionando worker ${WORKER_NAME_ARRAY[$index]}..."
  ssh "${SSH_OPTS[@]}" "opc@${WORKER_IP_ARRAY[$index]}" \
    "sudo /home/opc/k8s-bootstrap/scripts/04-worker.sh ${JOIN_COMMAND_ESCAPED}"
done

echo "Instalando MetalLB, ingress-nginx, cert-manager, Longhorn e ArgoCD..."
ssh "${SSH_OPTS[@]}" "opc@${CONTROL_PLANE_PUBLIC_IP}" \
  "sudo /home/opc/k8s-bootstrap/scripts/05-addons.sh '${METALLB_POOL}'"

echo "Cluster Kubernetes pronto. Validacao final:"
ssh "${SSH_OPTS[@]}" "opc@${CONTROL_PLANE_PUBLIC_IP}" "kubectl get nodes -o wide && kubectl get svc -n argocd argocd-server"
