# Wird von k3s automatisch aus /var/lib/rancher/k3s/server/manifests angewendet.
# Die HelmChart-CRs werden vom eingebauten k3s helm-controller ausgeführt.
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
type: Opaque
stringData:
  token: ${jsonencode(hcloud_token)}
  network: ${jsonencode(network_id)}
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-autoscaler
  namespace: kube-system
type: Opaque
stringData:
  HCLOUD_CLUSTER_CONFIG: ${jsonencode(cluster_config_b64)}
  HCLOUD_NETWORK: ${jsonencode(network_id)}
  HCLOUD_FIREWALL: ${jsonencode(firewall_id)}
  HCLOUD_SSH_KEY: ${jsonencode(ssh_key_id)}
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: hcloud-ccm
  namespace: kube-system
spec:
  repo: https://charts.hetzner.cloud
  chart: hcloud-cloud-controller-manager
%{ if ccm_version != "" ~}
  version: "${ccm_version}"
%{ endif ~}
  targetNamespace: kube-system
  valuesContent: |-
    # Netzwerk-ID kommt aus dem Secret "hcloud" (Key "network").
    # Routen-Management ist aus: k3s nutzt Flannel (VXLAN) über das private Netz.
    networking:
      enabled: false
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: hcloud-csi
  namespace: kube-system
spec:
  repo: https://charts.hetzner.cloud
  chart: hcloud-csi
%{ if csi_version != "" ~}
  version: "${csi_version}"
%{ endif ~}
  targetNamespace: kube-system
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  repo: https://kubernetes.github.io/autoscaler
  chart: cluster-autoscaler
%{ if autoscaler_version != "" ~}
  version: "${autoscaler_version}"
%{ endif ~}
  targetNamespace: kube-system
  valuesContent: |-
    cloudProvider: hetzner
    autoscalingGroups:
      - name: ${pool_name}
        minSize: ${worker_min}
        maxSize: ${worker_max}
        instanceType: ${upper(worker_server_type)}
        region: ${upper(location)}
    extraEnvSecrets:
      HCLOUD_TOKEN:
        name: hcloud
        key: token
      HCLOUD_CLUSTER_CONFIG:
        name: hcloud-autoscaler
        key: HCLOUD_CLUSTER_CONFIG
      HCLOUD_NETWORK:
        name: hcloud-autoscaler
        key: HCLOUD_NETWORK
      HCLOUD_FIREWALL:
        name: hcloud-autoscaler
        key: HCLOUD_FIREWALL
      HCLOUD_SSH_KEY:
        name: hcloud-autoscaler
        key: HCLOUD_SSH_KEY
