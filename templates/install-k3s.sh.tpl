#!/bin/bash
# Installiert k3s als "server" (Control Plane) oder "agent" (Worker).
set -euo pipefail

NETWORK_CIDR="${network_cidr}"

# Auf das private Netzwerk-Interface warten (wird von Hetzner per DHCP konfiguriert).
IFACE=""; PRIV_IP=""
for _ in $(seq 1 90); do
  read -r IFACE PRIV_IP < <(python3 - "$NETWORK_CIDR" <<'PY'
import ipaddress, json, subprocess, sys
net = ipaddress.ip_network(sys.argv[1])
for i in json.loads(subprocess.check_output(["ip", "-j", "-4", "addr"])):
    for a in i.get("addr_info", []):
        if ipaddress.ip_address(a["local"]) in net:
            print(i["ifname"], a["local"]); sys.exit(0)
PY
  ) || true
  [ -n "$IFACE" ] && break
  sleep 2
done
[ -n "$IFACE" ] || { echo "Kein privates Interface gefunden" >&2; exit 1; }

export INSTALL_K3S_VERSION="${k3s_version}"
export K3S_TOKEN="${k3s_token}"

%{ if role == "server" ~}
PUBLIC_IP=$(curl -sf http://169.254.169.254/hetzner/v1/metadata/public-ipv4 || true)

export INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --disable local-storage \
  --disable-cloud-controller \
  --kubelet-arg=cloud-provider=external \
  --node-ip=$PRIV_IP \
  --advertise-address=$PRIV_IP \
  --flannel-iface=$IFACE \
  --tls-san=$PRIV_IP $${PUBLIC_IP:+--tls-san=$PUBLIC_IP}"
%{ else ~}
export K3S_URL="https://${control_plane_ip}:6443"

# Warten bis die API der Control Plane erreichbar ist.
for _ in $(seq 1 90); do
  curl -ksf "$K3S_URL/ping" >/dev/null && break
  sleep 5
done

export INSTALL_K3S_EXEC="agent \
  --kubelet-arg=cloud-provider=external \
  --node-ip=$PRIV_IP \
  --flannel-iface=$IFACE"
%{ endif ~}

curl -sfL https://get.k3s.io | sh -

%{ if role == "server" ~}
# Der CCM darf NICHT über einen HelmChart-Job installiert werden: Die Helm-Jobs
# tolerieren den Taint node.cloudprovider.kubernetes.io/uninitialized nicht (Deadlock).
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until k3s kubectl get nodes >/dev/null 2>&1; do sleep 3; done
k3s kubectl apply -f "https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/download/${ccm_version}/ccm.yaml"
# Netzwerk setzen, damit der CCM die private IP (node-ip) kennt; Routen aus (Flannel).
k3s kubectl -n kube-system set env deploy/hcloud-cloud-controller-manager \
  HCLOUD_NETWORK="${network_id}" HCLOUD_NETWORK_ROUTES_ENABLED=false
%{ endif ~}
