data "openstack_networking_secgroup_v2" "this" {
  for_each = toset(var.security_groups)
  name     = each.value
}

resource "openstack_networking_port_v2" "public" {
  name               = "${var.instance_name}-public"
  network_id         = var.public_network_id
  admin_state_up     = true
  security_group_ids = [for sg in data.openstack_networking_secgroup_v2.this : sg.id]

  fixed_ip {
    subnet_id  = var.public_subnet_id
    ip_address = var.public_ip
  }
}

resource "openstack_networking_port_v2" "private" {
  name               = "${var.instance_name}-private"
  network_id         = var.private_network_id
  admin_state_up     = true
  security_group_ids = [for sg in data.openstack_networking_secgroup_v2.this : sg.id]

  fixed_ip {
    subnet_id  = var.private_subnet_id
    ip_address = var.private_ip
  }
}

resource "openstack_networking_port_v2" "management" {
  name               = "${var.instance_name}-management"
  network_id         = var.management_network_id
  admin_state_up     = true
  security_group_ids = [for sg in data.openstack_networking_secgroup_v2.this : sg.id]

  fixed_ip {
    subnet_id  = var.management_subnet_id
    ip_address = var.management_ip
  }
}

resource "openstack_compute_instance_v2" "this" {
  name        = var.instance_name
  flavor_name = var.flavor_name
  key_pair    = var.keypair
  user_data   = var.cloud_init

  block_device {
    uuid                  = var.image_name
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.root_volume_size_gb
    boot_index            = 0
    delete_on_termination = var.delete_root_volume_on_termination
  }

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
