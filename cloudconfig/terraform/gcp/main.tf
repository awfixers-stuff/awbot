# cloudconfigs/terraform/gcp/main.tf
# This is a simplified example. A real-world config would be more extensive.

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}-gke"
  location = var.gcp_region
  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 50
  }
}

# Output the Kubeconfig for connecting to the cluster
output "kubeconfig" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}
