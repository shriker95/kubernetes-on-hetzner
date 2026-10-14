# k3s auf Hetzner Cloud (Terraform)

Erzeugt: privates Netz, Firewall, SSH-Key, 1× k3s-Control-Plane. Per k3s-Auto-Deploy (HelmChart-CRs) werden installiert:
hcloud Cloud Controller Manager, hcloud CSI (Volumes) und der Kubernetes Cluster Autoscaler (Hetzner-Provider, Worker-Pool `pool1`, min/max über `worker_min`/`worker_pool_size`).

## Nutzung
```
cp terraform.tfvars.example terraform.tfvars   # anpassen
terraform init && terraform apply
$(terraform output -raw kubeconfig_command)    # nach ca. 2-3 Min.
KUBECONFIG=kubeconfig.yaml kubectl get nodes,pods -A
```

## Hinweise
- Der API-Token liegt als Secret im Cluster und in der Server-user_data (Hetzner-Metadaten) – Token nur mit Projektrechten dieses Clusters verwenden. Terraform-State enthält ihn ebenfalls.
- `user_data` ist per `ignore_changes` vom Neuanlegen ausgenommen; Änderungen an Charts danach per kubectl/Helm.
- Der CCM wird bewusst NICHT als HelmChart installiert (die Helm-Jobs tolerieren den Taint `uninitialized` nicht, Deadlock), sondern per `kubectl apply` des Release-Manifests `ccm.yaml` (Variable `ccm_version`); danach werden `HCLOUD_NETWORK` und `HCLOUD_NETWORK_ROUTES_ENABLED=false` gesetzt, damit die private Node-IP bekannt ist.
- Control Plane ist nicht getaintet, Workloads laufen dort mit. Bei `worker_min = 0` ist der Cluster mit 1 Node lauffähig.
- Nicht gegen die echte Hetzner-API getestet; die Chart-Wertenamen des Autoscalers (`autoscalingGroups`, `extraEnvSecrets`) bitte gegen das Chart-README prüfen.
