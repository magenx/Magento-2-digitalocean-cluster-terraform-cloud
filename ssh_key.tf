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
