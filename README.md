# Déploiement de VMs avec Terraform sur Proxmox

<p>
    <img src="https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white"/>
</p>


Ce projet crée plusieurs machines virtuelles Proxmox VE à partir d'un catalogue de templates, avec authentification par jeton API.

Il permet notamment de configurer, VM par VM :

- le template source et le nœud cible ;
- le VMID, le pool, les tags, le démarrage et la protection ;
- CPU, RAM, ballooning, BIOS/UEFI, TPM, machine QEMU et ordre de boot ;
- un ou plusieurs disques, leur datastore, taille, cache, TRIM, SSD et sauvegarde ;
- une ou plusieurs interfaces, bridge, VLAN access, trunks VLAN, MTU, firewall et MAC ;
- IPv4/IPv6 statique, DHCP ou SLAAC via cloud-init ;
- utilisateur, mot de passe, clés SSH et DNS cloud-init.

## Prérequis

- Terraform `>= 1.5`
- Proxmox VE avec des templates cloud-init existants
- QEMU Guest Agent installé et activé dans les templates si `agent.enabled = true`
- un bridge Proxmox VLAN-aware pour utiliser `vlan_id` ou `trunks`

Le provider utilisé est [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs).

## Préparer les templates

Chaque template doit contenir une image compatible cloud-init. Le template Debian existant peut rester le template par défaut :

```hcl
templates = {
  template-debian = {
    vm_id     = 9000
    node_name = "pve01"
  }

  template-ubuntu = {
    vm_id     = 9001
    node_name = "pve01"
  }
}
```

Une VM sélectionne ensuite son image avec `template = "template-debian"`. Ajouter un template ne demande aucune modification du code Terraform.

## Créer le jeton API

Créez un utilisateur et un token dédiés dans Proxmox. Accordez-lui, sur le pool ou le chemin concerné, les privilèges nécessaires au clonage et à la gestion des VMs et datastores. Le secret complet attendu par le provider est :

```text
utilisateur@realm!nom-du-token=secret-du-token
```

Ne stockez pas ce secret dans Git. Sous PowerShell :

```powershell
$env:TF_VAR_proxmox_api_token = "terraform@pve!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Utilisation

Copiez les deux exemples puis adaptez les templates, nœuds, datastores,
adresses et clés SSH :

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
Copy-Item virtual-machines.tfvars.example virtual-machines.tfvars
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform charge automatiquement `terraform..auto.tfvars` et `virtual-machines.auto.tfvars`.

Les deux fichiers réels sont ignorés par Git :

- `terraform.tfvars` contient la connexion, les paramètres globaux et les templates ;
- `virtual-machines.tfvars` contient uniquement les VMs.

## Réseau, VLAN et cloud-init

Les blocs `networks` pilotent simultanément la carte virtuelle Proxmox et `ipconfigN` dans cloud-init. Leur ordre est donc important :

```hcl
networks = [
  {
    bridge   = "vmbr0"
    vlan_id  = 120
    firewall = true
    ipv4 = {
      address = "192.168.120.21/24"
      gateway = "192.168.120.1"
    }
  },
  {
    bridge = "vmbr1"
    trunks = "220;221;222"
    ipv4 = {
      address = "dhcp"
    }
  }
]
```

- `vlan_id` configure un port access/tagué pour un VLAN.
- `trunks` expose plusieurs VLANs au système invité ; leur configuration interne doit alors être gérée dans la VM.
- Une seule passerelle par famille IP est généralement souhaitable.
- Omettez `gateway` avec `dhcp`, `auto` ou DHCPv6.

## Points d'attention

- La taille d'un disque cloné peut être augmentée, jamais réduite.
- `bios = "ovmf"` nécessite normalement un bloc `efi_disk`.
- Un TPM et certaines opérations matérielles peuvent imposer un arrêt de la VM.
- `type = "host"` pour le CPU maximise les performances mais réduit la portabilité entre nœuds différents.
- L'activation du VLAN sur la carte ne rend pas automatiquement le bridge Proxmox VLAN-aware.

Consultez [`terraform.tfvars.example`](terraform.tfvars.example) pour le
catalogue de templates et
[`virtual-machines.tfvars.example`](virtual-machines.tfvars.example) pour un
exemple complet multi-VM et multi-interface.

## Licence

Ce projet est distribué sous licence MIT. Consultez le fichier
[`LICENSE`](LICENSE).
