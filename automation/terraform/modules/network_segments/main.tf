resource "null_resource" "network_definition" {
  triggers = {
    public_cidr      = var.public_cidr
    private_cidr     = var.private_cidr
    management_cidr  = var.management_cidr
    public_gateway   = var.public_gateway
    management_gateway = var.management_gateway
  }
}
