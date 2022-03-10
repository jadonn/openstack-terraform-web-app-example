terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "1.44.0"
    }
  }
}

provider "openstack" {
}

data "openstack_identity_project_v3" "admin_project" {
    name = "admin"
}

data "openstack_networking_network_v2" "external_network" {
    name = "External"
}

data "openstack_networking_subnet_v2" "external_subnet" {
    name = "Internet"
}

data "openstack_images_image_v2" "centos_8_stream" {
    name = "CentOS 8 Stream (el8-x86_64)"
    most_recent = true
}

data "openstack_compute_flavor_v2" "c1_micro" {
    name = "c1.micro"
}

data "openstack_compute_flavor_v2" "c1_small" {
    name = "c1.small"
}


resource "openstack_compute_quotaset_v2" "admin_compute_quota" {
    project_id = "${data.openstack_identity_project_v3.admin_project.id}"
    ram = 512000
    cores = 64
    instances = 20
    key_pairs = 100
    server_groups = 10
    server_group_members = 10
    metadata_items = 128
    injected_files = 5
    injected_file_content_bytes = 10240
    injected_file_path_bytes = 255
}

resource "openstack_networking_quota_v2" "admin_network_quota" {
    project_id = "${data.openstack_identity_project_v3.admin_project.id}"
    network = 100
    subnet = 100
    subnetpool = 100
    port = 100
    router = 10
    floatingip = 50
    security_group = 20
    security_group_rule = 100
}

resource "openstack_networking_router_v2" "router" {
  name = "Router"
  admin_state_up = true
  external_network_id = "${data.openstack_networking_network_v2.external_network.id}"
}

resource "openstack_networking_network_v2" "web_tier" {
  name = "web_tier"
  admin_state_up = "true"
}

resource "openstack_networking_network_v2" "db_tier" {
  name = "db_tier"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "web_tier" {
  name = "web_tier"
  network_id = "${openstack_networking_network_v2.web_tier.id}"
  cidr = "192.168.4.0/24"
  ip_version = 4
}

resource "openstack_networking_subnet_v2" "db_tier" {
  name = "db_tier"
  network_id = "${openstack_networking_network_v2.db_tier.id}"
  cidr = "192.168.5.0/24"
  ip_version = 4
}

resource "openstack_networking_router_interface_v2" "web_tier_interface" {
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.web_tier.id}"
}

resource "openstack_networking_router_interface_v2" "db_tier_interface" {
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.db_tier.id}"
}

resource "openstack_networking_secgroup_v2" "jumpstation_1" {
    name = "Web Tier Jumpstation"
    description = "Web Tier Jumpstation access"
}

resource "openstack_networking_secgroup_rule_v2" "jumpstation_1_rule_ssh_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 22
    port_range_max = 22
    remote_ip_prefix = "0.0.0.0/0"
    security_group_id = "${openstack_networking_secgroup_v2.jumpstation_1.id}"
}

resource "openstack_networking_secgroup_v2" "web_tier" {
    name = "web_tier"
    description = "Access to web instances"
}

resource "openstack_networking_secgroup_rule_v2" "web_tier_ssh_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 22
    port_range_max = 22
    security_group_id = "${openstack_networking_secgroup_v2.web_tier.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.web_tier.id}"
}

resource "openstack_networking_secgroup_v2" "public_web" {
    name = "public_web"
    description = "Public HTTP/HTTPS access"
}

resource "openstack_networking_secgroup_rule_v2" "public_web_rule_http_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 80
    port_range_max = 80
    remote_ip_prefix = "0.0.0.0/0"
    security_group_id = "${openstack_networking_secgroup_v2.public_web.id}"
}
resource "openstack_networking_secgroup_rule_v2" "public_web_rule_https_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 443
    port_range_max = 443
    remote_ip_prefix = "0.0.0.0/0"
    security_group_id = "${openstack_networking_secgroup_v2.public_web.id}"
}

resource "openstack_networking_secgroup_v2" "web_from_load_balancer" {
    name = "web_from_load_balancer"
    description = "HTTP/HTTPS from load balancer to web_tier"
}

resource "openstack_networking_secgroup_rule_v2" "web_from_load_balancer_http_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 80
    port_range_max = 80
    security_group_id = "${openstack_networking_secgroup_v2.web_from_load_balancer.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.public_web.id}"
}

resource "openstack_networking_secgroup_rule_v2" "web_from_load_balancer_https_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 443
    port_range_max = 443
    remote_group_id = "${openstack_networking_secgroup_v2.public_web.id}"
    security_group_id = "${openstack_networking_secgroup_v2.web_from_load_balancer.id}"
}

resource "openstack_networking_secgroup_v2" "db_tier" {
    name = "db_tier"
    description = "Access to database instances"
}

resource "openstack_networking_secgroup_rule_v2" "db_tier_rule_ssh_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 22
    port_range_max = 22
    security_group_id = "${openstack_networking_secgroup_v2.db_tier.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.db_tier.id}"
}

resource "openstack_networking_secgroup_rule_v2" "db_tier_rule_mysql_web_tier" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 3306
    port_range_max = 3306
    security_group_id = "${openstack_networking_secgroup_v2.db_tier.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.web_tier.id}"
}

resource "openstack_networking_secgroup_rule_v2" "db_tier_rule_mysql_db_tier" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 3306
    port_range_max = 3306
    security_group_id = "${openstack_networking_secgroup_v2.db_tier.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.db_tier.id}"
}

resource "openstack_networking_secgroup_v2" "jumpstation_2" {
    name = "jumpstation_2"
    description = "DB Tier JumpStation access"
}

resource "openstack_networking_secgroup_rule_v2" "jumpstation_2_rule_ssh_ingress" {
    direction = "ingress"
    ethertype = "IPv4"
    protocol = "tcp"
    port_range_min = 22
    port_range_max = 22
    security_group_id = "${openstack_networking_secgroup_v2.jumpstation_2.id}"
    remote_group_id = "${openstack_networking_secgroup_v2.jumpstation_1.id}"
}

resource "openstack_blockstorage_volume_v3" "jumpstation_1" {
    name = "jumpstation_1"
    size = 25
}

resource "openstack_compute_instance_v2" "jumpstation_1" {
    name = "jumpstation_1"
    security_groups = [
        "${openstack_networking_secgroup_v2.jumpstation_1.name}",
        "${openstack_networking_secgroup_v2.web_tier.name}"
    ]
    network {
        name = "${openstack_networking_network_v2.web_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_micro.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.jumpstation_1.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "server_dev" {
    name = "server-dev"
    size = 50
}

resource "openstack_compute_instance_v2" "server_dev" {
    name = "server-dev"
    security_groups = [
        "${openstack_networking_secgroup_v2.web_tier.name}",
        "${openstack_networking_secgroup_v2.web_from_load_balancer.name}"
    ]
    network {
        name = "${openstack_networking_network_v2.web_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_small.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.server_dev.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "server_1" {
    name = "server-1"
    size = 50
}

resource "openstack_compute_instance_v2" "server_1" {
    name = "server-1"
    security_groups = [
        "${openstack_networking_secgroup_v2.web_tier.name}",
        "${openstack_networking_secgroup_v2.web_from_load_balancer.name}"
    ]
    network {
        name = "${openstack_networking_network_v2.web_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_small.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.server_1.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "load_balancer" {
    name = "load-balancer"
    size = 25
}

resource "openstack_compute_instance_v2" "load_balancer" {
    name = "load-balancer"
    security_groups = [
        "${openstack_networking_secgroup_v2.web_tier.name}",
        "${openstack_networking_secgroup_v2.public_web.name}"
    ]
    network {
        name = "${openstack_networking_network_v2.web_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_small.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.load_balancer.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "jumpstation_2" {
    name = "db-tier-jumpstation"
    size = 25
}

resource "openstack_compute_instance_v2" "jumpstation_2" {
    name = "db-tier-jumpstation"
    security_groups = [
        "${openstack_networking_secgroup_v2.jumpstation_2.name}",
        "${openstack_networking_secgroup_v2.db_tier.name}"
    ]

    network {
        name = "${openstack_networking_network_v2.db_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_micro.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.jumpstation_2.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "db_1" {
    name = "db-1"
    size = 50
}

resource "openstack_compute_instance_v2" "db_1" {
    name = "db-1"
    security_groups = [
        "${openstack_networking_secgroup_v2.db_tier.name}"
    ]

    network {
        name = "${openstack_networking_network_v2.db_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_small.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.db_1.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_blockstorage_volume_v3" "db_1_replica" {
    name = "db-1-repl-1"
    size = 50
}

resource "openstack_compute_instance_v2" "db_1_replica" {
    name = "db-1-repl-1"
    security_groups = [
        "${openstack_networking_secgroup_v2.db_tier.name}"
    ]

    network {
        name = "${openstack_networking_network_v2.db_tier.name}"
    }
    flavor_id = "${data.openstack_compute_flavor_v2.c1_small.id}"
    image_id = "${data.openstack_images_image_v2.centos_8_stream.id}"

    block_device {
        uuid = "${data.openstack_images_image_v2.centos_8_stream.id}"
        source_type = "image"
        destination_type = "local"
        boot_index = 0
    }

    block_device {
        uuid = "${openstack_blockstorage_volume_v3.db_1_replica.id}"
        source_type = "volume"
        destination_type = "volume"
        boot_index = 1
    }
}

resource "openstack_networking_floatingip_v2" "floatingip_jumpstation_1" {
    pool = "External"
    subnet_id = "${data.openstack_networking_subnet_v2.external_subnet.id}"
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_jumpstation_1" {
    floating_ip = "${openstack_networking_floatingip_v2.floatingip_jumpstation_1.address}"
    instance_id = "${openstack_compute_instance_v2.jumpstation_1.id}"
}

resource "openstack_networking_floatingip_v2" "floatingip_load_balancer" {
    pool = "External"
    subnet_id = "${data.openstack_networking_subnet_v2.external_subnet.id}"
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_load_balancer" {
    floating_ip = "${openstack_networking_floatingip_v2.floatingip_load_balancer.address}"
    instance_id = "${openstack_compute_instance_v2.load_balancer.id}"
}