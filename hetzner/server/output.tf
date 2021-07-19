output "ssh_commands" {
    value = format("ssh root@%s", hcloud_server.kubernetes-server.ipv4_address)
}
