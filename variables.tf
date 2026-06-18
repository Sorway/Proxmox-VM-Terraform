variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox VE, par exemple https://pve.example.com:8006/."
  type        = string

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint doit être une URL HTTPS."
  }
}

variable "proxmox_api_token" {
  description = "Jeton API au format utilisateur@realm!token=secret. Préférer la variable d'environnement TF_VAR_proxmox_api_token."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Autorise un certificat TLS auto-signé. À désactiver avec un certificat valide."
  type        = bool
  default     = false
}

variable "default_node_name" {
  description = "Nœud Proxmox cible par défaut."
  type        = string
}

variable "default_datastore_id" {
  description = "Datastore par défaut pour les disques et cloud-init."
  type        = string
  default     = "local-lvm"
}

variable "templates" {
  description = "Catalogue des templates Proxmox clonables, indexé par un nom logique."
  type = map(object({
    vm_id        = number
    node_name    = optional(string)
    datastore_id = optional(string)
    full_clone   = optional(bool, true)
  }))

  validation {
    condition     = length(var.templates) > 0
    error_message = "Au moins un template doit être déclaré."
  }
}

variable "virtual_machines" {
  description = "VMs à créer. La clé de map est un identifiant Terraform stable."
  type = map(object({
    name                = string
    template            = optional(string, "template-debian")
    vm_id               = optional(number)
    node_name           = optional(string)
    description         = optional(string, "Provisionnée par Terraform")
    tags                = optional(set(string), ["terraform"])
    pool_id             = optional(string)
    started             = optional(bool, true)
    on_boot             = optional(bool, true)
    protection          = optional(bool, false)
    stop_on_destroy     = optional(bool, true)
    reboot_after_update = optional(bool, true)
    bios                = optional(string, "seabios")
    machine             = optional(string, "pc")
    operating_system    = optional(string, "l26")
    scsi_hardware       = optional(string, "virtio-scsi-single")
    keyboard_layout     = optional(string, "fr")
    hotplug             = optional(string, "network,disk,usb")
    boot_order          = optional(list(string), ["scsi0"])

    cpu = optional(object({
      cores      = optional(number, 2)
      sockets    = optional(number, 1)
      type       = optional(string, "x86-64-v2-AES")
      flags      = optional(list(string), [])
      numa       = optional(bool, false)
      hotplugged = optional(number, 0)
      limit      = optional(number, 0)
      units      = optional(number)
      affinity   = optional(string)
    }), {})

    memory = optional(object({
      dedicated      = optional(number, 2048)
      floating       = optional(number, 0)
      shared         = optional(number, 0)
      hugepages      = optional(string)
      keep_hugepages = optional(bool, false)
    }), {})

    agent = optional(object({
      enabled       = optional(bool, true)
      trim          = optional(bool, true)
      type          = optional(string, "virtio")
      timeout       = optional(string, "15m")
      wait_for_ipv4 = optional(bool, true)
      wait_for_ipv6 = optional(bool, false)
      wait_enabled  = optional(bool, true)
    }), {})

    disks = optional(map(object({
      datastore_id = optional(string)
      size         = optional(number, 20)
      file_format  = optional(string, "raw")
      cache        = optional(string, "none")
      discard      = optional(string, "on")
      iothread     = optional(bool, true)
      ssd          = optional(bool, true)
      backup       = optional(bool, true)
      replicate    = optional(bool, true)
      aio          = optional(string, "io_uring")
      serial       = optional(string)
      })), {
      scsi0 = {
        size = 20
      }
    })

    networks = optional(list(object({
      bridge       = optional(string, "vmbr0")
      model        = optional(string, "virtio")
      mac_address  = optional(string)
      firewall     = optional(bool, false)
      disconnected = optional(bool, false)
      mtu          = optional(number)
      queues       = optional(number)
      rate_limit   = optional(number)
      vlan_id      = optional(number)
      trunks       = optional(string)
      ipv4 = optional(object({
        address = optional(string, "dhcp")
        gateway = optional(string)
      }), {})
      ipv6 = optional(object({
        address = optional(string)
        gateway = optional(string)
      }))
      })), [
      {
        bridge = "vmbr0"
        ipv4   = { address = "dhcp" }
      }
    ])

    cloud_init = optional(object({
      datastore_id = optional(string)
      interface    = optional(string, "ide2")
      username     = optional(string, "debian")
      password     = optional(string)
      ssh_keys     = optional(list(string), [])
      dns_domain   = optional(string)
      dns_servers  = optional(list(string), [])
    }), {})

    efi_disk = optional(object({
      datastore_id      = optional(string)
      file_format       = optional(string, "raw")
      type              = optional(string, "4m")
      pre_enrolled_keys = optional(bool, false)
    }))

    tpm_state = optional(object({
      datastore_id = optional(string)
      version      = optional(string, "v2.0")
    }))

    vga = optional(object({
      type   = optional(string, "std")
      memory = optional(number, 16)
    }), {})

    startup = optional(object({
      order      = optional(number, 3)
      up_delay   = optional(number, 30)
      down_delay = optional(number, 30)
    }), {})
  }))

  validation {
    condition     = alltrue([for vm in values(var.virtual_machines) : length(vm.networks) > 0])
    error_message = "Chaque VM doit avoir au moins une interface réseau."
  }

  validation {
    condition = alltrue(flatten([
      for vm in values(var.virtual_machines) : [
        for nic in vm.networks :
        nic.vlan_id == null || (nic.vlan_id >= 1 && nic.vlan_id <= 4094)
      ]
    ]))
    error_message = "Un VLAN doit être compris entre 1 et 4094."
  }
}
