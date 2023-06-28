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
  name        = digitalocean_projetc.this.name
  region      = var.region
  vpc_uuid    = digitalocean_vpc.this.id
  project_id  = digitalocean_project.this.id
  size        = var.size
  
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
  
  droplet_tag = "frontend"
}
//////////////////////////////////////////////////[ DIGITALOCEAN RESERVED IP ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create DigitalOcean reserved ip address
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_reserved_ip" "this" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "this" {
  ip_address = digitalocean_reserved_ip.this.ip_address
  droplet_id = digitalocean_droplet.this["varnish"].id
}
////////////////////////////////////////////////////[ DIGITALOCEAN DROPLETS ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create DigitalOcean droplets
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_droplet" "this" {
  for_each      = var.droplets
  image         = "debian-11"
  name          = "${digitalocean_project.this.name}-${each.key}"
  region        = var.region
  size          = var.size
  monitoring    = true
  vpc_uuid      = digitalocean_vpc.this.id
  ssh_keys      = [digitalocean_ssh_key.this.fingerprint]
  volume_ids    = each.key == "media" ? [digitalocean_volume.this.id] : null
  resize_disk   = false
  droplet_agent = true
  tags          = [
    each.key,
    digitalocean_tag.this.id
  ]
}
/////////////////////////////////////////////////[ DIGITALOCEAN MEDIA VOLUME ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create volume for media droplet storage
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_volume" "this" {
  region                  = var.region
  name                    = "${digitalocean_project.this.name}-media-volume"
  size                    = 120
  initial_filesystem_type = "ext4"
  description             = "Volume for media droplet @ ${digitalocean_project.this.name}"
}
//////////////////////////////////////////[ DIGITALOCEAN DROPLETS CONFIGURATION ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create DigitalOcean droplets configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "terraform_data" "this" {
  for_each = var.droplets

  connection {
      host        = digitalocean_droplet.this[each.key].ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.this.public_key_openssh
    }

  provisioner "remote-exec" {
    inline = [
      "cloud-init --file /tmp/cloud-init-config-${each.key}.yaml"
    ]
  }

  provisioner "file" {
    content     = <<-EOF
#cloud-config
chpasswd:
  list: |
    root:${random_password.this.result}
  expire: false
runcmd:
    - |
      curl -sSL -H "X-Config-Type: Cloud" \
      -H "Authorization: Bearer ${var.bearer}" "https://magenx.sh" | env \
      PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address) \
      SERVER_NAME="${each.key}" \
      DEBIAN_FRONTEND=noninteractive \
      TERMS="y" \
      ENV="${var.env}" \
      DOMAIN="${var.domain}" \
      DOWNLOAD_MAGENTO="${var.download_magento}" \
      VERSION_INSTALLED="${var.version_installed}" \
      APPLY_MAGENTO_CONFIG="${var.apply_magento_config}" \
      PHP_VERSION="${var.php_version}" \
      TIMEZONE="${var.timezone}" \
      LOCALE="${var.locale}" \
      CURRENCY="${var.currency}" \
      ADMIN_FIRST_NAME="${var.admin_first_name}" \
      ADMIN_LAST_NAME="${var.admin_last_name}" \
      ADMIN_LOGIN="${var.admin_login}" \
      ADMIN_EMAIL="${var.admin_email}" \
%{ if each.key != "frontend" ~}
      INSTALL_$${SERVER_NAME^^}="y" \
      $${SERVER_NAME^^}_SERVER_IP="$${PRIVATE_IP}" \
      bash -s -- lemp ${each.key} firewall
%{ else ~}
      INSTALL_NGINX="y" \
      INSTALL_PHP="y" \
      MARIADB_SERVER_IP="${digitalocean_droplet.this["mariadb"].ipv4_address_private}" \
      REDIS_SERVER_IP="${digitalocean_droplet.this["redis"].ipv4_address_private}" \
      RABBITMQ_SERVER_IP="${digitalocean_droplet.this["rabbitmq"].ipv4_address_private}" \
      VARNISH_SERVER_IP="${digitalocean_droplet.this["varnish"].ipv4_address_private}" \
      ELASTICSEARCH_SERVER_IP="${digitalocean_droplet.this["elasticsearch"].ipv4_address_private}" \
      MEDIA_SERVER_IP="${digitalocean_droplet.this["media"].ipv4_address_private}" \
      bash -s -- lemp magento install config firewall
%{ endif ~}
EOF

    destination = "/tmp/cloud-init-config-${each.key}.yaml"
  }
}
////////////////////////////////////////////////[ DIGITALOCEAN MANAGED DATABASES ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create managed database services [ mysql | redis ]
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_database_cluster" "this" {
  for_each   = var.database
  name       = "${digitalocean_project.this.name}-${each.key}"
  engine     = each.key
  version    = each.value.version
  size       = each.value.size
  region     = var.region
  node_count = each.value.node_count
  private_network_uuid = digitalocean_vpc.this.id
  eviction_policy      = each.key == "redis" ? "allkeys_lru" : null
  tags                 = [${digitalocean_project.this.name}-${each.key}]
}
////////////////////////////////////////////////[ DIGITALOCEAN PROJECT RESOURCES ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Assign resources to this project
# # ---------------------------------------------------------------------------------------------------------------------#
resource "digitalocean_project_resources" "this" {
  project   = digitalocean_project.this.id
  resources = [
    concat(values(digitalocean_droplet.services)[*].urn,values(digitalocean_database_cluster.this)[*].urn,[digitalocean_volume.this.urn],[digitalocean_loadbalancer.this.urn])
  ]
}
