terraform {
    required_version = ">= 1.0.0"
    required_providers {
        hcloud = {
            source  = "hetznercloud/hcloud"
            version = "~> 1.26.0"
        }
    }
}

provider "hcloud" {
    token = var.hcloud_token
}

resource "hcloud_ssh_key" "ssh_key" {
    name       = "ssh-key"
    public_key = file(var.ssh_public_key_file)
}

resource "hcloud_server" "kubernetes-server" {
    name        = "kubernetes-server"
    image       = "ubuntu-20.04"
    server_type = "cpx31"
    firewall_ids = [hcloud_firewall.firewall.id]

    ssh_keys = [
        hcloud_ssh_key.ssh_key.id,
    ]
}

resource "hcloud_firewall" "firewall" {
    name = "firewall"
    rule {
        direction = "in"
        protocol = "tcp"
        port = "22"
        source_ips = [
            "0.0.0.0/0",
            "::/0"
        ]
    }
    rule {
        direction = "in"
        protocol = "tcp"
        port = "6443"
        source_ips = [
            "0.0.0.0/0",
            "::/0"
        ]
    }
}


