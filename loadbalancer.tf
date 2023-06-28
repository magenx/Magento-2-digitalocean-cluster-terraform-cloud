/////////////////////////////////////////////////[ DIGITALOCEAN LOAD BALANCER ]///////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create load balancer
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_loadbalancer" "this" {
  name                   = digitalocean_projetc.this.name
  region                 = var.region
  vpc_uuid               = var.vpc_uuid
  size                   = var.size
  algorithm              = var.algorithm

  enable_proxy_protocol  = true
  redirect_http_to_https = true
  
  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"

  }

  healthcheck {
    protocol                 = "tcp"
    port                     = 80
    check_interval_seconds   = 10
    response_timeout_seconds = 5
    unhealthy_threshold      = 3
    healthy_threshold        = 5
  }
  
  droplet_tag = "loadbalancer"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign loadbalancer to this project
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_project_resources" "loadbalancer" {
  project   = digitalocean_project.this.id
  resources = [
    digitalocean_loadbalancer.this.urn
  ]
}
