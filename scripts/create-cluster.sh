#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

REGION=""
COMPARTMENT_OCID=""
TENANCY_OCID=""
USER_OCID=""
FINGERPRINT=""
OCI_PRIVATE_KEY_PATH=""
SSH_PUBLIC_KEY_FILE=""
SSH_PRIVATE_KEY_PATH="${HOME}/.ssh/kube.key"
SSH_KEY_COMMENT="k8s-oci-always-free"
ALLOWED_SOURCE_CIDR="null"
CONTROL_PLANE_OCPUS="1"
AUTO_APPROVE="false"

usage() {
  cat <<'EOF'
Uso:
  scripts/create-cluster.sh \
    --region sa-vinhedo-1 \
    --compartment-ocid ocid1.compartment.oc1..xxx \
    --tenancy-ocid ocid1.tenancy.oc1..xxx \
    --user-ocid ocid1.user.oc1..xxx \
    --fingerprint aa:bb:cc:dd:ee:ff \
    --oci-private-key-path ~/.oci/oci_api_key.pem \
    --auto-approve

Flags obrigatorias:
  --region
  --compartment-ocid

Credenciais OCI:
  Passe --tenancy-ocid, --user-ocid, --fingerprint e --oci-private-key-path,
  ou deixe essas flags vazias se o provider OCI ja estiver configurado em ~/.oci/config.

SSH:
  Se --ssh-public-key-file nao for informado, o script cria automaticamente:
    ~/.ssh/kube.key
    ~/.ssh/kube.key.pub

Opcoes:
  --ssh-public-key-file PATH     Chave publica SSH existente.
  --ssh-private-key-path PATH    Chave privada SSH. Padrao: ~/.ssh/kube.key.
  --allowed-source-cidr CIDR     Se omitido, o Terraform detecta seu IP publico e usa /32.
  --control-plane-ocpus N        Padrao: 1. Use 2 se houver cota.
  --auto-approve                 Executa terraform apply -auto-approve.
  -h, --help                     Mostra esta ajuda.
EOF
}

expand_path() {
  local path="$1"
  case "${path}" in
    "~") printf '%s\n' "${HOME}" ;;
    "~/"*) printf '%s/%s\n' "${HOME}" "${path#~/}" ;;
    *) printf '%s\n' "${path}" ;;
  esac
}

hcl_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="${2:?Valor ausente para --region}"
      shift 2
      ;;
    --compartment-ocid)
      COMPARTMENT_OCID="${2:?Valor ausente para --compartment-ocid}"
      shift 2
      ;;
    --tenancy-ocid)
      TENANCY_OCID="${2:?Valor ausente para --tenancy-ocid}"
      shift 2
      ;;
    --user-ocid)
      USER_OCID="${2:?Valor ausente para --user-ocid}"
      shift 2
      ;;
    --fingerprint)
      FINGERPRINT="${2:?Valor ausente para --fingerprint}"
      shift 2
      ;;
    --oci-private-key-path)
      OCI_PRIVATE_KEY_PATH="$(expand_path "${2:?Valor ausente para --oci-private-key-path}")"
      shift 2
      ;;
    --ssh-public-key-file)
      SSH_PUBLIC_KEY_FILE="$(expand_path "${2:?Valor ausente para --ssh-public-key-file}")"
      shift 2
      ;;
    --ssh-private-key-path)
      SSH_PRIVATE_KEY_PATH="$(expand_path "${2:?Valor ausente para --ssh-private-key-path}")"
      shift 2
      ;;
    --allowed-source-cidr)
      ALLOWED_SOURCE_CIDR="${2:?Valor ausente para --allowed-source-cidr}"
      shift 2
      ;;
    --control-plane-ocpus)
      CONTROL_PLANE_OCPUS="${2:?Valor ausente para --control-plane-ocpus}"
      shift 2
      ;;
    --auto-approve)
      AUTO_APPROVE="true"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Flag desconhecida: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v terraform >/dev/null 2>&1; then
  echo "Terraform nao encontrado no PATH." >&2
  exit 1
fi

if [[ -z "${REGION}" || -z "${COMPARTMENT_OCID}" ]]; then
  echo "Informe --region e --compartment-ocid." >&2
  usage >&2
  exit 1
fi

OCI_FIELDS=0
for value in "${TENANCY_OCID}" "${USER_OCID}" "${FINGERPRINT}" "${OCI_PRIVATE_KEY_PATH}"; do
  [[ -n "${value}" ]] && OCI_FIELDS=$((OCI_FIELDS + 1))
done

if [[ "${OCI_FIELDS}" -gt 0 && "${OCI_FIELDS}" -lt 4 ]]; then
  echo "Credenciais OCI incompletas. Informe tenancy, user, fingerprint e chave privada, ou omita todas para usar ~/.oci/config." >&2
  exit 1
fi

if [[ "${OCI_FIELDS}" -eq 0 && ! -f "${HOME}/.oci/config" ]]; then
  echo "Nao encontrei ~/.oci/config. Passe as credenciais OCI pelas flags do script." >&2
  exit 1
fi

if [[ -n "${OCI_PRIVATE_KEY_PATH}" && ! -r "${OCI_PRIVATE_KEY_PATH}" ]]; then
  echo "Chave privada da API OCI nao encontrada ou sem permissao de leitura: ${OCI_PRIVATE_KEY_PATH}" >&2
  exit 1
fi

if [[ -z "${SSH_PUBLIC_KEY_FILE}" ]]; then
  SSH_PUBLIC_KEY_FILE="${SSH_PRIVATE_KEY_PATH}.pub"
fi

if [[ ! -r "${SSH_PUBLIC_KEY_FILE}" || ! -r "${SSH_PRIVATE_KEY_PATH}" ]]; then
  if [[ -e "${SSH_PRIVATE_KEY_PATH}" || -e "${SSH_PUBLIC_KEY_FILE}" ]]; then
    echo "Par de chaves SSH incompleto ou sem permissao de leitura:" >&2
    echo "  privada: ${SSH_PRIVATE_KEY_PATH}" >&2
    echo "  publica: ${SSH_PUBLIC_KEY_FILE}" >&2
    exit 1
  fi

  if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "ssh-keygen nao encontrado no PATH. Instale o OpenSSH ou passe uma chave com --ssh-public-key-file." >&2
    exit 1
  fi

  echo "Gerando chave SSH em ${SSH_PRIVATE_KEY_PATH}..."
  mkdir -p "$(dirname "${SSH_PRIVATE_KEY_PATH}")"
  ssh-keygen -t ed25519 -C "${SSH_KEY_COMMENT}" -f "${SSH_PRIVATE_KEY_PATH}" -N ""
  chmod 700 "$(dirname "${SSH_PRIVATE_KEY_PATH}")"
  chmod 600 "${SSH_PRIVATE_KEY_PATH}"
  chmod 644 "${SSH_PUBLIC_KEY_FILE}"
fi

if [[ ! -r "${SSH_PUBLIC_KEY_FILE}" ]]; then
  echo "Chave publica SSH nao encontrada ou sem permissao de leitura: ${SSH_PUBLIC_KEY_FILE}" >&2
  exit 1
fi

if [[ ! -r "${SSH_PRIVATE_KEY_PATH}" ]]; then
  echo "Chave privada SSH nao encontrada ou sem permissao de leitura: ${SSH_PRIVATE_KEY_PATH}" >&2
  exit 1
fi

SSH_PUBLIC_KEY="$(tr -d '\n' < "${SSH_PUBLIC_KEY_FILE}")"

echo "Gerando ${TFVARS_FILE}..."
{
  printf 'region = '
  hcl_string "${REGION}"
  printf '\n'

  printf 'compartment_ocid = '
  hcl_string "${COMPARTMENT_OCID}"
  printf '\n\n'

  if [[ "${OCI_FIELDS}" -eq 4 ]]; then
    printf 'tenancy_ocid = '
    hcl_string "${TENANCY_OCID}"
    printf '\n'
    printf 'user_ocid = '
    hcl_string "${USER_OCID}"
    printf '\n'
    printf 'fingerprint = '
    hcl_string "${FINGERPRINT}"
    printf '\n'
    printf 'oci_private_key_path = '
    hcl_string "${OCI_PRIVATE_KEY_PATH}"
    printf '\n\n'
  fi

  printf 'ssh_public_key = '
  hcl_string "${SSH_PUBLIC_KEY}"
  printf '\n'
  printf 'ssh_private_key_path = '
  hcl_string "${SSH_PRIVATE_KEY_PATH}"
  printf '\n\n'

  if [[ "${ALLOWED_SOURCE_CIDR}" == "null" ]]; then
    printf 'allowed_source_cidr = null\n\n'
  else
    printf 'allowed_source_cidr = '
    hcl_string "${ALLOWED_SOURCE_CIDR}"
    printf '\n\n'
  fi

  printf 'control_plane_ocpus = %s\n' "${CONTROL_PLANE_OCPUS}"
  printf 'control_plane_memory_in_gbs = 6\n'
  printf 'ocpus = 1\n'
  printf 'memory_in_gbs = 6\n\n'

  printf 'vcn_cidr = "10.0.0.0/24"\n'
  printf 'subnet_cidr = "10.0.0.0/24"\n'
  printf 'metallb_pool = "10.0.0.240-10.0.0.250"\n\n'

  printf 'node_private_ips = {\n'
  printf '  kube   = "10.0.0.39"\n'
  printf '  kube02 = "10.0.0.135"\n'
  printf '  kube03 = "10.0.0.74"\n'
  printf '  kube04 = "10.0.0.118"\n'
  printf '}\n'
} >"${TFVARS_FILE}"

cd "${TERRAFORM_DIR}"

echo "Inicializando Terraform..."
terraform init

echo "Validando configuracao..."
terraform validate

if [[ "${AUTO_APPROVE}" == "true" ]]; then
  echo "Criando infraestrutura e executando bootstrap Kubernetes..."
  terraform apply -auto-approve
else
  echo "Criando infraestrutura e executando bootstrap Kubernetes..."
  terraform apply
fi

echo
echo "Acessos SSH:"
printf 'kube:   %s\n' "$(terraform output -raw ssh_kube)"
printf 'kube02: %s\n' "$(terraform output -raw ssh_kube02)"
printf 'kube03: %s\n' "$(terraform output -raw ssh_kube03)"
printf 'kube04: %s\n' "$(terraform output -raw ssh_kube04)"

echo
echo "ArgoCD:"
terraform output -raw argocd_temporary_endpoint

echo
echo "Kubeconfig:"
terraform output -raw kubectl_config_command
