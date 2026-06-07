# Projeto: Kubernetes OCI Always Free

## Objetivo

Transformar o laboratório Kubernetes criado manualmente na OCI em um projeto versionado no GitHub, usando Terraform para provisionamento da infraestrutura e scripts de bootstrap/automação para instalação do cluster Kubernetes.

Antes de alterar o projeto, leia:

- `docs/contexto-k8s-oci.md`
- `docs/runbook-manual.md`

## Stack

- OCI Oracle Cloud Infrastructure
- Terraform
- Oracle Linux 9 ARM64
- OCI Ampere A1 Flex
- kubeadm
- containerd
- Flannel CNI
- MetalLB
- ingress-nginx
- cert-manager
- Longhorn
- ArgoCD

## Topologia desejada

| Host | Função |
|---|---|
| kube | Control plane |
| kube02 | Worker / data-plane |
| kube03 | Worker / data-plane |
| kube04 | Worker / data-plane |

## Rede

- VCN: `Kube-VCN`
- CIDR da VCN: `10.0.0.0/24`
- Subnet pública: `VCN-Public`
- CIDR da subnet: `10.0.0.0/24`
- Internet Gateway: `GI-Kube-VCN`
- Route Table: rota default `0.0.0.0/0 -> Internet Gateway`
- MetalLB pool: `10.0.0.240-10.0.0.250`

## IPs privados usados no laboratório manual

| Host | IP privado |
|---|---|
| kube | `10.0.0.39` |
| kube02 | `10.0.0.135` |
| kube03 | `10.0.0.74` |
| kube04 | `10.0.0.118` |

Esses IPs podem mudar no Terraform, mas o projeto deve preferir IPs privados fixos para facilitar automação e documentação.

## Decisões técnicas

- O cluster foi criado com `kubeadm`.
- O control-plane roda no host `kube`.
- Os demais nós são workers.
- O CNI escolhido foi Flannel com CIDR de pods `10.244.0.0/16`.
- O runtime é `containerd` instalado via pacote `containerd.io` do repositório Docker CE, pois `containerd` não estava disponível nos repositórios padrão do Oracle Linux 9 ARM64.
- O `firewalld` foi desabilitado em todos os nós para simplificar o laboratório.
- Como o control-plane tinha apenas 1 OCPU, o `kubeadm init` precisou usar `--ignore-preflight-errors=NumCPU`.
- O ArgoCD foi exposto inicialmente via Service `LoadBalancer`, recebendo IP privado do MetalLB, e acessado externamente pelo NodePort HTTPS `30868` usando o IP público do nó `kube`.

## Diretrizes para implementação

- Não commitar secrets, chaves privadas, tokens do kubeadm, kubeconfig real ou OCIDs sensíveis.
- Criar variáveis Terraform para região, compartment, shape, quantidade de OCPU/memória, CIDR, IPs permitidos e chave pública SSH.
- Separar módulos Terraform por responsabilidade: network, security e compute.
- Gerar outputs úteis: IP público e privado dos nós, comandos SSH e endpoint temporário do ArgoCD.
- Preferir cloud-init ou Ansible para preparar os nós Linux.
- Manter manifests Kubernetes em diretórios separados por addon.
- Não deixar regras abertas para `0.0.0.0/0` em SSH ou NodePorts quando o objetivo for uso pessoal; preferir `meu_ip/32`.

## Estrutura sugerida

```text
.
├── AGENTS.md
├── README.md
├── terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   └── modules
│       ├── network
│       ├── security
│       └── compute
├── scripts
│   ├── 00-common.sh
│   ├── 01-containerd.sh
│   ├── 02-kubernetes.sh
│   ├── 03-control-plane.sh
│   └── 04-worker.sh
└── docs
    ├── contexto-k8s-oci.md
    └── runbook-manual.md
```
