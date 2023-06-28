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
