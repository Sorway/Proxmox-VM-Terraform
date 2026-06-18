output "virtual_machines" {
  description = "Informations utiles sur les VMs créées."
  value = {
    for key, vm in proxmox_virtual_environment_vm.proxmox_vm : key => {
      id                      = vm.id
      vm_id                   = vm.vm_id
      name                    = vm.name
      node_name               = vm.node_name
      ipv4_addresses          = vm.ipv4_addresses
      ipv6_addresses          = vm.ipv6_addresses
      network_interface_names = vm.network_interface_names
    }
  }
}
