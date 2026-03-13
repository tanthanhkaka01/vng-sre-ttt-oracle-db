resource "openstack_networking_port_v2" "public" {
  name           = "${var.instance_name}-public"
  network_id     = var.public_network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.public_subnet_id
    ip_address = var.public_ip
  }
}

resource "openstack_networking_port_v2" "private" {
  name           = "${var.instance_name}-private"
  network_id     = var.private_network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.private_subnet_id
    ip_address = var.private_ip
  }
}

resource "openstack_networking_port_v2" "management" {
  name           = "${var.instance_name}-management"
  network_id     = var.management_network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.management_subnet_id
    ip_address = var.management_ip
  }
}

resource "openstack_compute_instance_v2" "this" {
  name            = var.instance_name
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.keypair
  security_groups = var.security_groups
  user_data       = var.cloud_init

  network {
    port = openstack_networking_port_v2.public.id
  }

  network {
    port = openstack_networking_port_v2.private.id
  }

  network {
    port = openstack_networking_port_v2.management.id
  }
}
