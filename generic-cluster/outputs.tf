output "cluster_instances" {
  value = {
    id = ["${aws_instance.main.*.id}"]
    fqdn = ["${aws_route53_record.private_a.*.fqdn}"]
    fqdn_alias = ["${aws_route53_record.private_a_alias.*.fqdn}"]
    availability_zone = ["${aws_instance.main.*.availability_zone}"]
    network_interface_id = ["${aws_instance.main.*.network_interface_id}"]
    primary_network_interface_id = ["${aws_instance.main.*.primary_network_interface_id}"]
    private_ip = ["${aws_instance.main.*.private_ip}"]
    public_ip = ["${aws_eip.main.*.public_ip}"]
    subnet_id = ["${aws_instance.main.*.subnet_id}"]
    ebs_volume1_id = ["${aws_ebs_volume.volume1.*.id}"]
    ebs_volume2_id = ["${aws_ebs_volume.volume2.*.id}"]
    ebs_volume3_id = ["${aws_ebs_volume.volume3.*.id}"]
  }
}

output "cluster_security_group_id" {
  value = "${aws_security_group.main.id}"
}
