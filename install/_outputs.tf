# Output Server IP
output "node_ip" {
  value = try("${libvirt_domain.target.network_interface.0.addresses.0}","")
}