# Kubernetes OCI Always Free

Projeto para criar um cluster Kubernetes na Oracle Cloud Infrastructure usando Terraform, instancias Ampere A1 Flex ARM64, Oracle Linux 9, kubeadm, containerd, Flannel, MetalLB, ingress-nginx, cert-manager, Longhorn e ArgoCD.

## O que o Terraform cria

- VCN `Kube-VCN` com CIDR `10.0.0.0/24`
- Subnet publica `VCN-Public`
- Internet Gateway `GI-Kube-VCN`
- Route table com `0.0.0.0/0` para o Internet Gateway
- NSG liberando todo trafego a partir do IP publico atual do usuario
- NSG liberando todo trafego interno da VCN
- 4 instancias Oracle Linux 9 ARM64:
  - `kube`: control-plane
  - `kube02`, `kube03`, `kube04`: workers
- IPs privados fixos para facilitar acesso, automacao e documentacao
- Bootstrap automatico do Kubernetes e addons

## Requisitos

- Terraform `>= 1.6`
- Conta OCI configurada para o provider Terraform
- Conta OCI com Pay As You Go habilitado
- OpenSSH client com `ssh-keygen`
- Cota para instancias `VM.Standard.A1.Flex`
- A maquina local precisa conseguir acessar a OCI via Internet

Este projeto foi pensado para usar recursos elegiveis ao **Always Free** da OCI, mas na pratica pode ser necessario habilitar a conta como **Pay As You Go** para conseguir criar as instancias Ampere A1 Flex. A ideia continua sendo manter o laboratorio dentro dos limites gratuitos.

Antes de aplicar, confira no painel da OCI:

- se a regiao escolhida tem capacidade para `VM.Standard.A1.Flex`;
- se a tenancy tem cota disponivel para Ampere A1;
- se OCPUs e memoria configuradas cabem no limite Always Free;
- se nenhum recurso extra pago sera criado fora deste projeto.

O provider OCI pode usar a configuracao padrao em `~/.oci/config` ou variaveis de ambiente, conforme a documentacao oficial do provider.

## Uso rapido

O caminho mais simples e rodar o script principal a partir da raiz do projeto:

```bash
scripts/create-cluster.sh --region sa-vinhedo-1 --compartment-ocid ocid1.tenancy.oc1.. --auto-approve
```

O script:

- gera `terraform/terraform.tfvars`;
- roda `terraform init`;
- roda `terraform validate`;
- roda `terraform apply`;
- pega os outputs de acesso;
- deixa o Terraform executar o bootstrap via SSH nas maquinas.
- gera automaticamente `~/.ssh/kube.key` e `~/.ssh/kube.key.pub`, se voce nao informar uma chave SSH.

Esse comando considera que voce ja tem o provider OCI configurado em `~/.oci/config`.

Se preferir passar as credenciais da OCI pelo comando, use tambem:

```text
--tenancy-ocid ocid1.tenancy.oc1..example
--user-ocid ocid1.user.oc1..example
--fingerprint aa:bb:cc:dd:ee:ff
--oci-private-key-path ~/.oci/oci_api_key.pem
```

Se quiser usar uma chave SSH propria, adicione:

```bash
--ssh-public-key-file ~/.ssh/sua-chave.pub \
--ssh-private-key-path ~/.ssh/sua-chave
```

Para ver todas as opcoes:

```bash
scripts/create-cluster.sh --help
```

## Uso com Terraform direto

Entre no diretorio Terraform:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` e preencha:

```hcl
region               = "sa-vinhedo-1"
compartment_ocid     = "ocid1.compartment.oc1..example"
tenancy_ocid         = "ocid1.tenancy.oc1..example"
user_ocid            = "ocid1.user.oc1..example"
fingerprint          = "aa:bb:cc:dd:ee:ff"
oci_private_key_path = "~/.oci/oci_api_key.pem"
ssh_public_key       = "ssh-rsa AAAA... usuario@maquina"
ssh_private_key_path = "~/.ssh/kube.key"
```

Se `allowed_source_cidr = null`, o Terraform detecta o IP publico atual do usuario com `https://api.ipify.org` e cria a regra como `<seu-ip>/32`.

Depois execute:

```bash
terraform init
terraform apply
```

Ao final do `apply`, o bootstrap local acessa as instancias via SSH, instala containerd, kubeadm/kubelet/kubectl, inicializa o control-plane, instala os addons e junta os workers.

## Acessos

O Terraform gera um resumo unico com os principais acessos:

```bash
terraform output -raw cluster_access
```

Esse resumo mostra:

- comandos SSH para `kube`, `kube02`, `kube03` e `kube04`;
- URL temporaria do ArgoCD;
- comando para buscar a senha inicial do ArgoCD;
- comando para copiar o kubeconfig;
- IPs publicos e privados dos nodes;
- CIDR liberado nas regras de acesso.

Para acessar o ArgoCD:

```bash
terraform output -raw cluster_access
```

Usuario inicial:

```text
admin
```

## Observacoes

- Nao coloque chave privada, kubeconfig real, tokens ou OCIDs sensiveis no Git.
- O control-plane usa `--ignore-preflight-errors=NumCPU` para funcionar com 1 OCPU.
- Se houver cota, prefira `control_plane_ocpus = 2`.
- O MetalLB usa IPs privados da VCN; por isso o acesso externo inicial ao ArgoCD usa NodePort no IP publico do node `kube`.
