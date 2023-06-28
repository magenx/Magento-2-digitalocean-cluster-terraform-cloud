# Configure the DigitalOcean Cloud provider
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.28.1"
    }
  }
}

provider "digitalocean" {
  token = var.do_tocken
}
//////////////////////////////////////////////////[ DIGITALOCEAN PROJECT ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create DigitalOcean project
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_project" "this" {
  name        = var.project
  description = "A project to represent development resources."
  purpose     = "Web Application"
  environment =  var.environment
}
///////////////////////////////////////////////////[ DIGITALOCEAN NETWORK ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_vpc" "this" {
  name     = digitalocean_projetc.this.name
  region   = var.region
  ip_range = var.vpc_cidr
}
/////////////////////////////////////////////////[ DIGITALOCEAN SSH KEY ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create DigitalOcean ssh key and password
# # ---------------------------------------------------------------------------------------------------------------------#
# Generate ED25519 ssh key
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Add public ssh key to DO
resource "digitalocean_ssh_key" "this" {
  name       = digitalocean_project.this.name
  public_key = tls_private_key.this.public_key_openssh
}

# Generate ssh password for debug
resource "random_password" "this" {
  length = 16
}
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
////////////////////////////////////////////////[ DIGITALOCEAN PROJECT RESOURCES ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Assign resources to this project
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_project_resources" "this" {
  project   = digitalocean_project.this.id
  resources = [
    digitalocean_loadbalancer.this.urn
  ]
}
