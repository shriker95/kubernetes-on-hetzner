output "control_plane_ipv4" {
  value = hcloud_server.control_plane.ipv4_address
}

output "network_id" {
  value = hcloud_network.this.id
}

output "kubeconfig_command" {
  description = "Holt die kubeconfig und setzt die öffentliche IP ein (erst nach Abschluss von cloud-init nutzbar, ca. 2-3 Minuten)."
  value       = "ssh root@${hcloud_server.control_plane.ipv4_address} cat /etc/rancher/k3s/k3s.yaml | sed 's#127.0.0.1#${hcloud_server.control_plane.ipv4_address}#' > kubeconfig.yaml"
}
