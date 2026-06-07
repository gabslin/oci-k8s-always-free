# Runbook manual do cluster Kubernetes OCI

Este documento resume os comandos executados manualmente para criação do cluster Kubernetes em Oracle Linux 9 ARM64 na OCI.

## 1. Configuração inicial de SSH

No computador local:

```bash
mkdir -p ~/.ssh
cp kube.key ~/.ssh/kube.key
chmod 400 ~/.ssh/kube.key
nano ~/.ssh/config
```

Exemplo de configuração:

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
```

Acesso:

```bash
ssh kube
ssh kube02
ssh kube03
ssh kube04
```

## 2. Hostname

Executar em cada nó.

No `kube`:

```bash
sudo hostnamectl set-hostname kube
```

No `kube02`:

```bash
sudo hostnamectl set-hostname kube02
```

No `kube03`:

```bash
sudo hostnamectl set-hostname kube03
```

No `kube04`:

```bash
sudo hostnamectl set-hostname kube04
```

## 3. Arquivo /etc/hosts

Executar em todos os nós:

```bash
sudo tee -a /etc/hosts <<'EOF'
10.0.0.39   kube
10.0.0.135  kube02
10.0.0.74   kube03
10.0.0.118  kube04
EOF
```

## 4. Desabilitar swap

Executar em todos os nós:

```bash
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
free -h
```

## 5. Módulos de kernel

Executar em todos os nós:

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

## 6. Sysctl para Kubernetes

Executar em todos os nós:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system
```

## 7. Desabilitar firewalld

Executar em todos os nós:

```bash
sudo systemctl disable --now firewalld
```

## 8. Instalar containerd

No Oracle Linux 9 ARM64, o pacote `containerd` não foi encontrado nos repositórios padrão. Foi usado o pacote `containerd.io` do repositório Docker CE.

Executar em todos os nós:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf makecache
sudo dnf install -y containerd.io
```

Gerar configuração:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Ativar cgroup systemd:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

Subir serviço:

```bash
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

Validar:

```bash
containerd --version
```

## 9. Repositório Kubernetes

Executar em todos os nós:

```bash
cat <<'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
EOF
```

## 10. Instalar kubelet, kubeadm e kubectl

Executar em todos os nós:

```bash
sudo dnf install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

## 11. Inicializar control-plane

Executar apenas no `kube`:

```bash
sudo kubeadm init \
  --apiserver-advertise-address=10.0.0.39 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU
```

Salvar o comando `kubeadm join` gerado ao final.

## 12. Configurar kubectl no control-plane

Executar no `kube`:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Validar:

```bash
kubectl get nodes
```

## 13. Instalar Flannel CNI

Executar no `kube`:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Validar:

```bash
kubectl get pods -A
```

## 14. Adicionar workers

Executar em `kube02`, `kube03` e `kube04` o comando gerado pelo `kubeadm init`.

Exemplo:

```bash
sudo kubeadm join 10.0.0.39:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Validar no control-plane:

```bash
kubectl get nodes -o wide
```

## 15. Instalar MetalLB

Executar no `kube`:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=180s
```

Criar pool de IPs:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: pool-vcn
  namespace: metallb-system
spec:
  addresses:
  - 10.0.0.240-10.0.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-vcn
  namespace: metallb-system
spec:
  ipAddressPools:
  - pool-vcn
EOF
```

## 16. Instalar ingress-nginx

Executar no `kube`:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.3/deploy/static/provider/cloud/deploy.yaml
```

Validar:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## 17. Instalar cert-manager

Executar no `kube`:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml
```

Validar:

```bash
kubectl get pods -n cert-manager
```

## 18. Preparar dependências do Longhorn

Executar em todos os nós:

```bash
sudo dnf install -y iscsi-initiator-utils nfs-utils
sudo systemctl enable --now iscsid
```

## 19. Instalar Longhorn

Executar no `kube`:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.11.1/deploy/longhorn.yaml
```

Validar:

```bash
kubectl get pods -n longhorn-system
kubectl get storageclass
```

## 20. Instalar ArgoCD

Executar no `kube`:

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Expor serviço:

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"LoadBalancer"}}'
```

Verificar service:

```bash
kubectl get svc -n argocd argocd-server
```

Exemplo obtido:

```text
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
argocd-server   LoadBalancer   10.110.53.94   10.0.0.241    80:31863/TCP,443:30868/TCP
```

Como o `EXTERNAL-IP` é privado, acessar via NodePort usando o IP público do nó `kube`:

```text
https://<IP_PUBLICO_KUBE>:30868
```

A porta `30868` deve estar liberada na OCI para o IP público do usuário.

Pegar senha inicial:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Usuário:

```text
admin
```

## 21. Validações úteis

Nós:

```bash
kubectl get nodes -o wide
```

Pods do sistema:

```bash
kubectl get pods -A
```

Services LoadBalancer:

```bash
kubectl get svc -A | grep LoadBalancer
```

StorageClasses:

```bash
kubectl get storageclass
```

Eventos:

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

## 22. Próximos passos para automação

- Criar Terraform para VCN, subnet, Internet Gateway, route table, NSG/security lists e instâncias.
- Gerar inventário Ansible a partir dos outputs do Terraform.
- Criar scripts idempotentes para preparação Linux.
- Criar bootstrap separado para control-plane e workers.
- Versionar manifests Kubernetes dos addons.
- Criar README com arquitetura, requisitos e passo a passo.
