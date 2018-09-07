#
# Module's Arguments -----------------------------------------------------------
#

variable "cluster_name" {
  description = "The name of the cluster"
  type = "string"
}

variable "route53_zones" {
  description = "A mapping of Route53 Zones (private, private_reverse and private_public)"
  default = {
    private = {}
    private_reverse = {}
    private_public = {}
  }
}

variable "append_region_code" {
  description = "Whether to append the AWS Region Code to the instance DNS ALIAS"
  default = false
}

variable "vpc_id" {
  description = "The VPC ID where the instance will be deployed."
}

variable "internet_facing" {
  description = "Whether the instance will have a Public IP."
  default = false
}

variable "az_count" {
  description = "The amount of Availability Zones."
  default = 1
}
variable "az_server_count" {
  description = "The amount of servers per Availability Zones."
  default = 1
}

variable "element_prefix" {
  description = "Adds a prefix to the element (number) in the hostname."
  default = ""
}

variable "instance_type" {
  description = "The instance type. Updates to this field will trigger a stop/start of the EC2 instance. "
  default = "t2.micro"
}

variable "instance_tags" {
  description = "A mapping of tags to assign to the resource."
  default = {}
}

variable "instance_os" {
  description = "The OS to be installed on the instance (ubuntu|ubuntu-bionic, ubuntu-xenial, ubuntu-trusty, centos)"
  default = "ubuntu"
}

variable "key_name" {
  description = "The key name to use for the instance."
  default = "devops"
}

variable "source_dest_check" {
  description = "Whether to allow traffic when the destination address does not match the instance."
  default = true
}

variable "root_block_device" {
  description = "Customize details about the root block device of the instance."
  default = {}
}
locals {
  root_block_device = "${merge(
    map(
      "volume_type", "gp2",
      "volume_size", 8,
      "iops", 400,
      "delete_on_termination", true
    ),
    var.root_block_device
  )}"
}

variable "ebs_volume1" {
  description = "A mapping of attributes for External EBS Volume 1 (size, type & iops)."
  default = {}
}
variable "ebs_volume2" {
  description = "A mapping of attributes for External EBS Volume 2 (size, type & iops)."
  default = {}
}
variable "ebs_volume3" {
  description = "A mapping of attributes for External EBS Volume 3 (size, type & iops)."
  default = {}
}
locals {
  ebs_volume1 = "${merge(map("size", 0, "type", "gp2", "iops", 100), var.ebs_volume1)}"
  ebs_volume2 = "${merge(map("size", 0, "type", "gp2", "iops", 100), var.ebs_volume2)}"
  ebs_volume3 = "${merge(map("size", 0, "type", "gp2", "iops", 100), var.ebs_volume3)}"
}

variable "ansible_playbook" {
  description = "The name of the Ansible Playbook to invoke during host provisioning."
  default = "ipa-host-add.yml"
}

variable "ansible_user" {
  description = "The Remote User to be used by Ansible during host provisioning (ubuntu or centos)."
  default = "ubuntu"
}

variable "ansible_private_key" {
  description = "The path of the SSH Private Key to be used by Ansible during host provisioning."
  default = "~/.ssh/id_rsa-terraform"
}

#
# Data Sources and Locals ------------------------------------------------------
#

# Stage
#
locals {
  stage = "${terraform.workspace == "production" ? "prod" : "test" }"
}

# Retrieve latest AMI
#
data "aws_ami" "ubuntu_bionic" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "ubuntu_xenial" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "ubuntu_trusty" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "centos" {
  most_recent = true
  owners = ["679593333241"]

  filter {
    name = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS ENA*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  ami_id = {
    ubuntu-bionic = "${data.aws_ami.ubuntu_bionic.id}"
    ubuntu-xenial = "${data.aws_ami.ubuntu_xenial.id}"
    ubuntu-trusty = "${data.aws_ami.ubuntu_trusty.id}"
    ubuntu = "${data.aws_ami.ubuntu_bionic.id}"
    centos = "${data.aws_ami.centos.id}"
  }
}

# Retrieve current region (from provider)
#
data "aws_region" "selected" {}
locals {
  region_code = {
    us-east-1 = "ue1"
    us-east-2 = "ue2"
    us-west-1 = "uw1"
    us-west-2 = "uw2"
  }
}

# Retrieve VPC
#
data "aws_vpc" "selected" {
  state = "available"
  id = "${var.vpc_id}"
}

# Retrieve list of AZs
#
data "aws_availability_zones" "selected" {
  state = "available"
}
locals {
  availability_zones = "${slice(sort(data.aws_availability_zones.selected.names), 0, var.az_count)}"
}

# Retrieve Subnets
#
data "aws_subnet" "selected" {
  count = "${length(local.availability_zones)}"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${element(local.availability_zones, count.index)}"

  tags {
    type = "${var.internet_facing ? "public" : "private"}"
  }
}

# Compute server count (total)
#
locals {
  server_count = "${length(data.aws_subnet.selected.*.id) * var.az_server_count}"
}

# Render user-data from template file
#
data "template_file" "user_data" {
  count = "${local.server_count}"
  template = "${file("${path.module}/user-data/init.sh")}"

  vars {
    hostname = "${format("%s-%s%02d-%s%s.%s",
      var.cluster_name,
      var.element_prefix,
      count.index + 1,
      local.region_code[data.aws_region.selected.name],
      substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1),
      lookup(var.route53_zones["private"], "name")
    )}"
  }
}
