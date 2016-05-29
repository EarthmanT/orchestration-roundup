variable "network" {
    type = "string"
    default = "e21c474e-26bb-4b3e-97a9-580577db5207"
}

resource "openstack_networking_secgroup_v2" "all_group" {
  name = "all_group"
  description = "All Servers"
}

resource "openstack_networking_secgroup_v2" "mongo_group" {
  name = "mongo_group"
  description = "Mongo Servers"
}

resource "openstack_networking_secgroup_v2" "nodejs_group" {
  name = "nodejs_group"
  description = "NodeJS Servers"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.all_group.id}"
}

resource "openstack_networking_secgroup_rule_v2" "http_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 80
  port_range_max = 80
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.all_group.id}"
}

resource "openstack_networking_secgroup_rule_v2" "mongo_rulea" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 27017
  port_range_max = 27017
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.mongo_group.id}"
}

resource "openstack_networking_secgroup_rule_v2" "mongo_ruleb" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 28017
  port_range_max = 28017
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.mongo_group.id}"
}

resource "openstack_networking_secgroup_rule_v2" "nodejs_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 8080
  port_range_max = 8080
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.nodejs_group.id}"
}

resource "openstack_compute_floatingip_v2" "terraform_mongo_fip" {
  pool = "external"
}

resource "openstack_compute_floatingip_v2" "terraform_nodejs_fip" {
  pool = "external"
}

resource "openstack_compute_instance_v2" "terraform_mongo_host" {
  name = "terraform_mongo_host"
  image_id = "6c3047c6-17b1-4aaf-a657-9229bb481e50"
  flavor_id = "9cf6e43b-e191-47ca-8665-f8592e2d6227"
  key_pair = "terraform-demo"
  floating_ip = "${openstack_compute_floatingip_v2.terraform_mongo_fip.address}"
  security_groups = ["all_group", "mongo_group"]
  network = {
    uuid = "${var.network}"
  }
  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      host = "${openstack_compute_floatingip_v2.terraform_mongo_fip.address}"
      private_key = "${file("~/.ssh/terraform-demo.pem")}"
    }
    script = "./provision/provision_mongo.sh"
  }
}

resource "openstack_compute_instance_v2" "terraform_nodejs_host" {
  name = "terraform_nodejs_host"
  image_id = "6c3047c6-17b1-4aaf-a657-9229bb481e50"
  flavor_id = "9cf6e43b-e191-47ca-8665-f8592e2d6227"
  key_pair = "terraform-demo"
  floating_ip = "${openstack_compute_floatingip_v2.terraform_nodejs_fip.address}"
  security_groups = ["all_group", "nodejs_group"]
  network = {
    uuid = "${var.network}"
  }
  depends_on = ["openstack_compute_instance_v2.terraform_mongo_host"]
  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      host = "${openstack_compute_floatingip_v2.terraform_nodejs_fip.address}"
      private_key = "${file("~/.ssh/terraform-demo.pem")}"
    }
    inline = ["echo ${openstack_compute_floatingip_v2.terraform_mongo_fip.address} mongo_host | sudo tee -a /etc/hosts"]
  }
  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      host = "${openstack_compute_floatingip_v2.terraform_nodejs_fip.address }"
      private_key = "${file("~/.ssh/terraform-demo.pem")}"
    }
    script = "./provision/provision_nodejs.sh"
  }
}
