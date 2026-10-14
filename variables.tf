variable "hcloud_token" {
  description = "Hetzner Cloud API-Token (Read & Write). Wird auch an CCM, CSI und Autoscaler übergeben."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  type    = string
  default = "k3s"
}

variable "ssh_public_key" {
  description = "Öffentlicher SSH-Schlüssel für Control Plane und autoskalierte Worker."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs, die per SSH (22) und Kubernetes-API (6443) zugreifen dürfen, z. B. [\"203.0.113.4/32\"]."
  type        = list(string)
}

variable "extra_inbound_tcp_ports" {
  description = "Zusätzlich öffentlich erreichbare TCP-Ports (z. B. Ingress)."
  type        = list(string)
  default     = ["80", "443"]
}

variable "location" {
  description = "Hetzner-Standort (fsn1, nbg1, hel1, ...)."
  type        = string
  default     = "fsn1"
}

variable "network_zone" {
  type    = string
  default = "eu-central"
}

variable "network_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "control_plane_private_ip" {
  type    = string
  default = "10.0.1.1"
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "control_plane_server_type" {
  description = "Servertyp der Control Plane (cax11 = Arm64)."
  type        = string
  default     = "cax11"
}

variable "worker_server_type" {
  description = "Servertyp der autoskalierten Worker. Architektur muss zu worker_arch passen."
  type        = string
  default     = "cax11"
}

variable "worker_arch" {
  description = "Architektur der Worker-Servertypen: arm64 (cax*) oder amd64 (cx*/cpx*)."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "amd64"], var.worker_arch)
    error_message = "worker_arch muss arm64 oder amd64 sein."
  }
}

variable "worker_min" {
  type    = number
  default = 0
}

variable "worker_max" {
  type    = number
  default = 5
}

variable "k3s_version" {
  description = "Gepinnte k3s-Version (INSTALL_K3S_VERSION), z. B. v1.33.5+k3s1."
  type        = string
  default     = "v1.33.5+k3s1"
}

variable "ccm_chart_version" {
  description = "Version des Helm-Charts hcloud-cloud-controller-manager. Leer = neueste."
  type        = string
  default     = ""
}

variable "csi_chart_version" {
  description = "Version des Helm-Charts hcloud-csi. Leer = neueste."
  type        = string
  default     = ""
}

variable "autoscaler_chart_version" {
  description = "Version des Helm-Charts cluster-autoscaler. Leer = neueste."
  type        = string
  default     = ""
}
