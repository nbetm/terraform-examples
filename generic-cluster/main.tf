#
# EC2 Instances and EIP --------------------------------------------------------
#

resource "aws_instance" "main" {
  count = "${local.server_count}"
  subnet_id = "${element(data.aws_subnet.selected.*.id, count.index)}"
  ami = "${local.ami_id[var.instance_os]}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.main.id}"]
  user_data = "${element(data.template_file.user_data.*.rendered, count.index)}"
  associate_public_ip_address = "${var.internet_facing}"
  source_dest_check = "${var.source_dest_check}"

  root_block_device {
    volume_size = "${local.root_block_device["volume_size"]}"
    volume_type = "${local.root_block_device["volume_type"]}"
    iops = "${local.root_block_device["iops"]}"
    delete_on_termination = "${local.root_block_device["delete_on_termination"]}"
  }
  volume_tags {
    Name = "${format("%s-%s%02d-%s%s",
      var.cluster_name,
      var.element_prefix,
      count.index + 1,
      local.region_code[data.aws_region.selected.name],
      substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1)
    )}"
  }

  tags = "${merge(
    map(
      "Name", "${format("%s-%s%02d-%s%s",
        var.cluster_name,
        var.element_prefix,
        count.index + 1,
        local.region_code[data.aws_region.selected.name],
        substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1)
      )}",
      "ansible_managed", "true",
      "category", "other",
      "subcat", "other",
      "system", "${var.cluster_name}",
      "subsystem", "${var.cluster_name}",
      "stage", "${local.stage}"
    ),
    var.instance_tags
  )}"

  lifecycle {
    ignore_changes = ["ami"]
  }
}

# Only if var.internet_facing == true
#
resource "aws_eip" "main" {
  count = "${var.internet_facing ? local.server_count : 0}"
  instance = "${element(aws_instance.main.*.id, count.index)}"
  vpc = true
}

#
# EBS Volumes (external) -------------------------------------------------------
#
# Available EBS Device Names: /dev/sd[f-p]
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
#
resource "aws_ebs_volume" "volume1" {
  count = "${local.ebs_volume1["size"] > 0 ? local.server_count : 0}"
  size = "${local.ebs_volume1["size"]}"
  type = "${local.ebs_volume1["type"]}"
  iops = "${local.ebs_volume1["iops"]}"
  availability_zone = "${element(data.aws_subnet.selected.*.availability_zone, count.index)}"

  tags {
    Name = "${format("%s-%s%02d-%s%s-volume1",
      var.cluster_name,
      var.element_prefix,
      count.index + 1,
      local.region_code[data.aws_region.selected.name],
      substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1)
    )}"
  }
}
resource "aws_volume_attachment" "volume1" {
  count = "${local.ebs_volume1["size"] > 0 ? local.server_count : 0}"
  volume_id   = "${element(aws_ebs_volume.volume1.*.id, count.index)}"
  instance_id = "${element(aws_instance.main.*.id, count.index)}"
  device_name = "/dev/sdf"
}

resource "aws_ebs_volume" "volume2" {
  count = "${local.ebs_volume2["size"] > 0 ? local.server_count : 0}"
  size = "${local.ebs_volume2["size"]}"
  type = "${local.ebs_volume2["type"]}"
  iops = "${local.ebs_volume2["iops"]}"
  availability_zone = "${element(data.aws_subnet.selected.*.availability_zone, count.index)}"

  tags {
    Name = "${format("%s-%s%02d-%s%s-volume2",
      var.cluster_name,
      var.element_prefix,
      count.index + 1,
      local.region_code[data.aws_region.selected.name],
      substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1)
    )}"
  }
}
resource "aws_volume_attachment" "volume2" {
  count = "${local.ebs_volume2["size"] > 0 ? local.server_count : 0}"
  volume_id   = "${element(aws_ebs_volume.volume2.*.id, count.index)}"
  instance_id = "${element(aws_instance.main.*.id, count.index)}"
  device_name = "/dev/sdg"
}

resource "aws_ebs_volume" "volume3" {
  count = "${local.ebs_volume3["size"] > 0 ? local.server_count : 0}"
  size = "${local.ebs_volume3["size"]}"
  type = "${local.ebs_volume3["type"]}"
  iops = "${local.ebs_volume3["iops"]}"
  availability_zone = "${element(data.aws_subnet.selected.*.availability_zone, count.index)}"

  tags {
    Name = "${format("%s-%s%02d-%s%s-volume3",
      var.cluster_name,
      var.element_prefix,
      count.index + 1,
      local.region_code[data.aws_region.selected.name],
      substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1)
    )}"
  }
}
resource "aws_volume_attachment" "volume3" {
  count = "${local.ebs_volume3["size"] > 0 ? local.server_count : 0}"
  volume_id   = "${element(aws_ebs_volume.volume3.*.id, count.index)}"
  instance_id = "${element(aws_instance.main.*.id, count.index)}"
  device_name = "/dev/sdh"
}

#
# Route53 Records --------------------------------------------------------------
#

resource "aws_route53_record" "private_a" {
  count = "${local.server_count}"
  zone_id = "${lookup(var.route53_zones["private"], "zone_id")}"
  name = "${format("%s-%s%02d-%s%s.%s",
    var.cluster_name,
    var.element_prefix,
    count.index + 1,
    local.region_code[data.aws_region.selected.name],
    substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1),
    lookup(var.route53_zones["private"], "name")
  )}"
  type = "A"
  ttl = "600"
  records = ["${element(aws_instance.main.*.private_ip, count.index)}"]

  depends_on = [
    "aws_volume_attachment.volume1",
    "aws_volume_attachment.volume2",
    "aws_volume_attachment.volume3"
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command = "${var.ansible_playbook}"
    interpreter = [
      "ansible-playbook",
      "--user",
      "${var.ansible_user}",
      "--private-key",
      "${var.ansible_private_key}",
      "--limit",
      "tag_Name_${replace(element(split(".", self.name), 0), "-", "_")}"
    ]
  }

  provisioner "local-exec" {
    when = "destroy"
    working_dir = "${path.module}/ansible"
    command = "ipa-host-delete.yml"
    interpreter = [
      "ansible-playbook",
      "--extra-vars",
      "${format("fqdn=%s", self.name)}"
    ]
  }
}
resource "aws_route53_record" "private_a_alias" {
  count = "${local.server_count}"
  zone_id = "${lookup(var.route53_zones["private"], "zone_id")}"
  name = "${format("%s-%s%02d%s%s.%s",
    var.cluster_name,
    var.element_prefix,
    count.index + 1,
    var.append_region_code ? "-" : "",
    var.append_region_code ? local.region_code[data.aws_region.selected.name] : "",
    lookup(var.route53_zones["private"], "name")
  )}"
  type = "A"

  alias {
    name = "${element(aws_route53_record.private_a.*.fqdn, count.index)}"
    zone_id = "${lookup(var.route53_zones["private"], "zone_id")}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "private_ptr" {
  count = "${local.server_count}"
  zone_id = "${lookup(var.route53_zones["private_reverse"], "zone_id")}"
  name = "${format("%s.%s.%s.%s.in-addr.arpa.",
    element(split(".", element(aws_instance.main.*.private_ip, count.index)) ,3),
    element(split(".", element(aws_instance.main.*.private_ip, count.index)) ,2),
    element(split(".", element(aws_instance.main.*.private_ip, count.index)) ,1),
    element(split(".", element(aws_instance.main.*.private_ip, count.index)) ,0)
  )}"
  type = "PTR"
  ttl = "600"
  records = ["${element(aws_route53_record.private_a.*.fqdn, count.index)}"]
}

resource "aws_route53_record" "private_public_a" {
  count = "${local.server_count}"
  zone_id = "${lookup(var.route53_zones["private_public"], "zone_id")}"
  name = "${format("%s-%s%02d-%s%s.%s",
    var.cluster_name,
    var.element_prefix,
    count.index + 1,
    local.region_code[data.aws_region.selected.name],
    substr(element(data.aws_subnet.selected.*.availability_zone, count.index), -1, 1),
    lookup(var.route53_zones["private_public"], "name")
  )}"
  type = "A"
  ttl = "600"
  records = ["${element(aws_instance.main.*.private_ip, count.index)}"]
}
resource "aws_route53_record" "private_public_a_alias" {
  count = "${local.server_count}"
  zone_id = "${lookup(var.route53_zones["private_public"], "zone_id")}"
  name = "${format("%s-%s%02d%s%s.%s",
    var.cluster_name,
    var.element_prefix,
    count.index + 1,
    var.append_region_code ? "-" : "",
    var.append_region_code ? local.region_code[data.aws_region.selected.name] : "",
    lookup(var.route53_zones["private_public"], "name")
  )}"
  type = "A"

  alias {
    name = "${element(aws_route53_record.private_public_a.*.fqdn, count.index)}"
    zone_id = "${lookup(var.route53_zones["private_public"], "zone_id")}"
    evaluate_target_health = true
  }
}

#
# Security Groups --------------------------------------------------------------
#

resource "aws_security_group" "main" {
  name = "${var.cluster_name}-ec2-sg"
  description = "SG for ${var.cluster_name} ec2 instances"
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Name = "${var.cluster_name}-ec2-sg"
  }
}

resource "aws_security_group_rule" "icmp_echo_all_in" {
  type = "ingress"
  from_port = 8
  to_port = "-1"
  protocol = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.main.id}"
}

resource "aws_security_group_rule" "localnet_all_in" {
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["10.0.0.0/8"]
  security_group_id = "${aws_security_group.main.id}"
}

resource "aws_security_group_rule" "all_out" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.main.id}"
}
