locals {
  pool_name = "pool1"
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "hcloud_ssh_key" "this" {
  name       = var.cluster_name
  public_key = var.ssh_public_key
}

resource "hcloud_network" "this" {
  name     = var.cluster_name
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "this" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

resource "hcloud_firewall" "this" {
  name = var.cluster_name

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.admin_cidrs
  }

  rule {
    description = "Kubernetes API"
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = var.admin_cidrs
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = toset(var.extra_inbound_tcp_ports)
    content {
      description = "tcp/${rule.value}"
      direction   = "in"
      protocol    = "tcp"
      port        = rule.value
      source_ips  = ["0.0.0.0/0", "::/0"]
    }
  }
}

# ---------------------------------------------------------------------------
# cloud-init für autoskalierte Worker (wird vom Cluster Autoscaler genutzt)
# ---------------------------------------------------------------------------
locals {
  install_script_vars = {
    network_cidr     = var.network_cidr
    k3s_version      = var.k3s_version
    k3s_token        = random_password.k3s_token.result
    control_plane_ip = var.control_plane_private_ip
  }

  worker_cloud_init = "#cloud-config\n${yamlencode({
    write_files = [{
      path        = "/usr/local/bin/install-k3s.sh"
      permissions = "0700"
      content     = templatefile("${path.module}/templates/install-k3s.sh.tpl", merge(local.install_script_vars, { role = "agent" }))
    }]
    runcmd = ["/usr/local/bin/install-k3s.sh"]
  })}"

  # Neues Konfigurationsformat des Hetzner-Autoscalers (ersetzt HCLOUD_CLOUD_INIT/HCLOUD_IMAGE).
  cluster_config_b64 = base64encode(jsonencode({
    imagesForArch = {
      (var.worker_arch) = var.image
    }
    nodeConfigs = {
      (local.pool_name) = {
        cloudInit = local.worker_cloud_init
      }
    }
  }))

  manifests = templatefile("${path.module}/templates/manifests.yaml.tpl", {
    hcloud_token       = var.hcloud_token
    network_id         = tostring(hcloud_network.this.id)
    firewall_id        = tostring(hcloud_firewall.this.id)
    ssh_key_id         = tostring(hcloud_ssh_key.this.id)
    cluster_config_b64 = local.cluster_config_b64
    pool_name          = local.pool_name
    worker_min         = var.worker_min
    worker_max         = var.worker_max
    worker_server_type = var.worker_server_type
    location           = var.location
    ccm_version        = var.ccm_chart_version
    csi_version        = var.csi_chart_version
    autoscaler_version = var.autoscaler_chart_version
  })

  control_plane_cloud_init = "#cloud-config\n${yamlencode({
    write_files = [
      {
        path        = "/usr/local/bin/install-k3s.sh"
        permissions = "0700"
        content     = templatefile("${path.module}/templates/install-k3s.sh.tpl", merge(local.install_script_vars, { role = "server" }))
      },
      {
        path        = "/var/lib/rancher/k3s/server/manifests/hcloud.yaml"
        permissions = "0600"
        content     = local.manifests
      },
    ]
    runcmd = ["/usr/local/bin/install-k3s.sh"]
  })}"
}

# ---------------------------------------------------------------------------
# Control Plane (k3s server)
# ---------------------------------------------------------------------------
resource "hcloud_server" "control_plane" {
  name         = "${var.cluster_name}-cp-1"
  server_type  = var.control_plane_server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.this.id]
  firewall_ids = [hcloud_firewall.this.id]
  user_data    = local.control_plane_cloud_init

  network {
    network_id = hcloud_network.this.id
    ip         = var.control_plane_private_ip
  }

  labels = {
    cluster = var.cluster_name
    role    = "control-plane"
  }

  depends_on = [hcloud_network_subnet.this]

  lifecycle {
    ignore_changes = [user_data]
  }
}
