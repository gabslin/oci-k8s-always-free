# Contexto do laboratório Kubernetes na OCI

## Resumo

Foi criado um laboratório Kubernetes na Oracle Cloud Infrastructure usando instâncias ARM64 Ampere A1 Flex com Oracle Linux 9. O objetivo é transformar a configuração manual em um projeto reaproveitável com Terraform e automação para disponibilização no GitHub.

O cluster segue o modelo:

- `kube`: control-plane
- `kube02`, `kube03`, `kube04`: data-plane / workers

A instalação do Kubernetes foi feita com `kubeadm`, usando `containerd` como runtime e Flannel como CNI.

## Componentes instalados no cluster

- Kubernetes v1.33.x
- containerd
- Flannel CNI
- MetalLB
- ingress-nginx
- cert-manager
- Longhorn
- ArgoCD

## Infraestrutura OCI

### VCN

- Nome: `Kube-VCN`
- CIDR: `10.0.0.0/24`

### Subnet

- Nome: `VCN-Public`
- Tipo: pública
- CIDR: `10.0.0.0/24`

### Internet Gateway

- Nome: `GI-Kube-VCN`
- Estado: habilitado

### Route Table

A subnet pública precisa estar associada a uma route table com a seguinte regra:

```text
Destino: 0.0.0.0/0
Target: Internet Gateway GI-Kube-VCN
```

Durante a criação manual houve problema de timeout no SSH porque a subnet pública estava associada a uma route table sem rota default para Internet.

### Segurança

Foram usadas regras de entrada para permitir acesso administrativo a partir do IP público do usuário.

Regras principais:

```text
TCP 22    origem: MEU_IP/32
TCP 30868 origem: MEU_IP/32
```

A porta `30868` foi usada para acessar o ArgoCD via NodePort HTTPS no IP público do nó `kube`.

## Instâncias

Shape usado:

```text
VM.Standard.A1.Flex
```

Sistema operacional:

```text
Oracle Linux 9 ARM64
```

Hosts usados no laboratório manual:

| Host | Papel | IP privado |
|---|---|---|
| kube | Control-plane | `10.0.0.39` |
| kube02 | Worker | `10.0.0.135` |
| kube03 | Worker | `10.0.0.74` |
| kube04 | Worker | `10.0.0.118` |

## SSH

Foi usada uma chave chamada:

```text
kube.key
```

Configuração local sugerida em `~/.ssh/config`:

```sshconfig
Host kube
    HostName <IP_PUBLICO_KUBE>
    User opc
    IdentityFile ~/.ssh/kube.key

Host kube02
    HostName <IP_PUBLICO_KUBE02>
    User opc
    IdentityFile ~/.ssh/kube.key

Host kube03
    HostName <IP_PUBLICO_KUBE03>
    User opc
    IdentityFile ~/.ssh/kube.key

Host kube04
    HostName <IP_PUBLICO_KUBE04>
    User opc
    IdentityFile ~/.ssh/kube.key

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 10
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 8h
```

Permissões:

```bash
chmod 600 ~/.ssh/config
chmod 400 ~/.ssh/kube.key
```

## Kubernetes

O cluster foi criado com:

```bash
sudo kubeadm init \
  --apiserver-advertise-address=10.0.0.39 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU
```

O parâmetro `--ignore-preflight-errors=NumCPU` foi necessário porque o control-plane tinha apenas 1 OCPU. Para uma versão mais estável do projeto, é recomendado usar 2 OCPUs no control-plane, se houver cota disponível.

## CNI

O CNI escolhido foi Flannel:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

O CNI é aplicado apenas uma vez a partir do control-plane. Os pods do Flannel sobem automaticamente nos demais nós.

## MetalLB

O MetalLB foi usado para fornecer serviços do tipo `LoadBalancer` dentro da VCN.

Pool configurado:

```text
10.0.0.240-10.0.0.250
```

Como esse pool usa IPs privados da VCN, os serviços `LoadBalancer` não ficam acessíveis diretamente pela Internet. Para acesso externo inicial, foi usado NodePort no IP público do nó.

## NGINX Ingress

O ingress-nginx foi instalado para expor aplicações via Ingress.

Manifest usado:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.3/deploy/static/provider/cloud/deploy.yaml
```

## cert-manager

O cert-manager foi instalado para automatizar emissão e renovação de certificados TLS, principalmente quando o cluster passar a usar DNS e Ingress HTTPS.

Uso futuro esperado:

- `argocd.dominio.com`
- `grafana.dominio.com`
- `n8n.dominio.com`
- `typebot.dominio.com`

## Longhorn

O Longhorn foi instalado como storage distribuído para Kubernetes.

Ele será útil para workloads com estado, como:

- PostgreSQL
- Grafana
- Prometheus
- MinIO
- n8n
- aplicações com PVC

Dependências necessárias nos nós:

```bash
sudo dnf install -y iscsi-initiator-utils nfs-utils
sudo systemctl enable --now iscsid
```

## ArgoCD

O ArgoCD foi instalado no namespace `argocd`.

Ele foi exposto inicialmente com:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'
```

O serviço recebeu IP privado do MetalLB:

```text
10.0.0.241
```

Como o IP é privado, o acesso externo foi feito via NodePort HTTPS:

```text
https://IP_PUBLICO_DO_KUBE:30868
```

A porta `30868` precisa estar liberada no NSG/Security List da OCI para o IP público do usuário.
