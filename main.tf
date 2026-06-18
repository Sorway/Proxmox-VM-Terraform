check "templates_exist" {
  assert {
    condition = alltrue([
      for vm in values(var.virtual_machines) : contains(keys(var.templates), vm.template)
    ])
    error_message = "Chaque virtual_machines[*].template doit correspondre à une clé de var.templates."
  }
}

moved {
  from = proxmox_virtual_environment_vm.this
  to   = proxmox_virtual_environment_vm.proxmox_vm
}

resource "proxmox_virtual_environment_vm" "proxmox_vm" {
  for_each = var.virtual_machines

  name                = each.value.name
  description         = each.value.description
  node_name           = coalesce(each.value.node_name, var.default_node_name)
  vm_id               = each.value.vm_id
  tags                = each.value.tags
  pool_id             = each.value.pool_id
  started             = each.value.started
  on_boot             = each.value.on_boot
  protection          = each.value.protection
  stop_on_destroy     = each.value.stop_on_destroy
  reboot_after_update = each.value.reboot_after_update
  bios                = each.value.bios
  machine             = each.value.machine
  keyboard_layout     = each.value.keyboard_layout
  scsi_hardware       = each.value.scsi_hardware
  hotplug             = each.value.hotplug
  boot_order          = each.value.boot_order

  clone {
    vm_id        = var.templates[each.value.template].vm_id
    node_name    = coalesce(var.templates[each.value.template].node_name, var.default_node_name)
    datastore_id = coalesce(var.templates[each.value.template].datastore_id, var.default_datastore_id)
    full         = var.templates[each.value.template].full_clone
    retries      = 3
  }

  cpu {
    cores      = each.value.cpu.cores
    sockets    = each.value.cpu.sockets
    type       = each.value.cpu.type
    flags      = each.value.cpu.flags
    numa       = each.value.cpu.numa
    hotplugged = each.value.cpu.hotplugged
    limit      = each.value.cpu.limit
    units      = each.value.cpu.units
    affinity   = each.value.cpu.affinity
  }

  memory {
    dedicated      = each.value.memory.dedicated
    floating       = each.value.memory.floating
    shared         = each.value.memory.shared
    hugepages      = each.value.memory.hugepages
    keep_hugepages = each.value.memory.keep_hugepages
  }

  agent {
    enabled = each.value.agent.enabled
    trim    = each.value.agent.trim
    type    = each.value.agent.type
    timeout = each.value.agent.timeout

    wait_for_ip {
      ipv4    = each.value.agent.wait_for_ipv4
      ipv6    = each.value.agent.wait_for_ipv6
      enabled = each.value.agent.wait_enabled
    }
  }

  operating_system {
    type = each.value.operating_system
  }

  dynamic "disk" {
    for_each = each.value.disks

    content {
      interface    = disk.key
      datastore_id = coalesce(disk.value.datastore_id, var.default_datastore_id)
      size         = disk.value.size
      file_format  = disk.value.file_format
      cache        = disk.value.cache
      discard      = disk.value.discard
      iothread     = disk.value.iothread
      ssd          = disk.value.ssd
      backup       = disk.value.backup
      replicate    = disk.value.replicate
      aio          = disk.value.aio
      serial       = disk.value.serial
    }
  }

  dynamic "network_device" {
    for_each = each.value.networks

    content {
      bridge       = network_device.value.bridge
      model        = network_device.value.model
      mac_address  = network_device.value.mac_address
      firewall     = network_device.value.firewall
      disconnected = network_device.value.disconnected
      mtu          = network_device.value.mtu
      queues       = network_device.value.queues
      rate_limit   = network_device.value.rate_limit
      vlan_id      = network_device.value.vlan_id
      trunks       = network_device.value.trunks
    }
  }

  initialization {
    datastore_id = coalesce(each.value.cloud_init.datastore_id, var.default_datastore_id)
    interface    = each.value.cloud_init.interface

    dns {
      domain  = each.value.cloud_init.dns_domain
      servers = each.value.cloud_init.dns_servers
    }

    dynamic "ip_config" {
      for_each = each.value.networks

      content {
        ipv4 {
          address = ip_config.value.ipv4.address
          gateway = ip_config.value.ipv4.gateway
        }

        dynamic "ipv6" {
          for_each = ip_config.value.ipv6 == null ? [] : [ip_config.value.ipv6]

          content {
            address = ipv6.value.address
            gateway = ipv6.value.gateway
          }
        }
      }
    }

    user_account {
      username = each.value.cloud_init.username
      password = each.value.cloud_init.password != null ? each.value.cloud_init.password : (
        each.value.cloud_init.username == "debian" ? "debian" : null
      )
      keys = each.value.cloud_init.ssh_keys
    }
  }

  dynamic "efi_disk" {
    for_each = each.value.efi_disk == null ? [] : [each.value.efi_disk]

    content {
      datastore_id      = coalesce(efi_disk.value.datastore_id, var.default_datastore_id)
      file_format       = efi_disk.value.file_format
      type              = efi_disk.value.type
      pre_enrolled_keys = efi_disk.value.pre_enrolled_keys
    }
  }

  dynamic "tpm_state" {
    for_each = each.value.tpm_state == null ? [] : [each.value.tpm_state]

    content {
      datastore_id = coalesce(tpm_state.value.datastore_id, var.default_datastore_id)
      version      = tpm_state.value.version
    }
  }

  vga {
    type   = each.value.vga.type
    memory = each.value.vga.memory
  }

  startup {
    order      = tostring(each.value.startup.order)
    up_delay   = tostring(each.value.startup.up_delay)
    down_delay = tostring(each.value.startup.down_delay)
  }
}
