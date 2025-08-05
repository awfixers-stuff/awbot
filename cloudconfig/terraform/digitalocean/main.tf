# cloudconfigs/terraform/digitalocean/main.tf
# This is a simplified example. A real-world config would be more extensive.

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_kubernetes_cluster" "primary" {
  name    = "${var.cluster_name}-doks"
  region  = var.do_region
  version = "1.28.2-do.0" # Specify a valid DOKS version

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
  }
}

# Output the Kubeconfig for connecting to the cluster
output "kube_config" {
  value     = digitalocean_kubernetes_cluster.primary.kube_config.0.raw_config
  sensitive = true
}

output "cluster_name" {
  value = digitalocean_kubernetes_cluster.primary.name
}
