#########################################
###### Provider & Modules
#########################################

provider "aws" {
    version     = "~> 0.1"
    region      = "${var.aws_region}"
}

provider "random" {
    version = "~> 1.2"
}

#########################################
###### Common Variables
#########################################

variable "openshift_release" {
    description = "Openshift Release for base image name"
}

variable "master_count" {
    default = 1
}

variable "infra_count" {
    default = 1
}

variable "app_count" {
    default = 1
}

variable "prefix" {
    type    = "string"
    default = ""
    description = "Prefix for account-wide resources"
}

variable "cluster_zone" {
    type    = "string"
    description = "Cluster DNS zone (API)"
}

variable "cluster_zone_id" {
    type    = "string"
    description = "Cluster DNS zone (API)"
}

variable "apps_zone" {
    type    = "string"
    description = "Cluster apps DNS zone"
}

variable "apps_zone_id" {
    type    = "string"
    description = "Cluster apps DNS zone"
}

variable "user" {
    type    = "string"
    default = "centos"
    description = "Username for login"
}

variable "cluster_id" {
    type    = "string"
}
#########################################
###### Provider specific variables
#########################################

variable "aws_user_id" {
    type = "string"
    description = "Account user id"
}

variable "aws_resource_group" {
    type        = "string"
    description = "AWS Resource group"
}

variable "aws_region" {
    type    = "string"
    description = "AWS region only (no zone)"
}

variable "aws_zones" {
    type = "string"
}

variable "aws_instance_bastion" {
    type    = "string"
    default = "t2.medium"
    description = "Instance type for bastion host"
}

variable "aws_instance_master" {
    type    = "string"
    default = "t2.large"
    description = "Instance type for master node hosts"
}

variable "aws_instance_infra" {
    type    = "string"
    default = "t2.xlarge"
    description = ""
    description = "Instance type for infra node hosts"
}

variable "aws_instance_app" {
    type    = "string"
    default = "t2.xlarge"
    description = "Instance type for app node hosts"
}

variable "aws_key_name" {
    type    = "string"
    default = "getupcloud"
    description = "Name of AWS Key for ssh private key file"
}

variable "aws_disable_api_termination" {
    default = false
    description = "Disable AWS IAM termination protection"
}

variable "ami_bastion_image_name_filter" {
    default = "GetupEngine Bastion"
}

variable "ami_master_image_name_filter" {
    default = "GetupEngine Master"
}

variable "ami_infra_image_name_filter" {
    default = "GetupEngine Infra"
}

variable "ami_app_image_name_filter" {
    default = "GetupEngine App"
}

locals {
    aws_bucket_name = "${var.prefix}registry-${random_string.suffix.result}"
    aws_zones       = ["${split(" ", trimspace(var.aws_zones))}"]
    aws_zones_count = "${length(local.aws_zones)}"
}

#########################################
###### Provider specific data sources
#########################################

data "aws_ami" "centos_bastion" {
  most_recent = true

  filter {
    name   = "name"
#    values = ["${var.ami_bastion_image_name_filter} ${var.openshift_release}"]
    values = ["${var.ami_bastion_image_name_filter}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

data "aws_ami" "centos_master" {
  most_recent = true

  filter {
    name   = "name"
#    values = ["${var.ami_master_image_name_filter} ${var.openshift_release}"]
    values = ["${var.ami_master_image_name_filter}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

data "aws_ami" "centos_infra" {
  most_recent = true

  filter {
    name   = "name"
#    values = ["${var.ami_infra_image_name_filter} ${var.openshift_release}"]
    values = ["${var.ami_infra_image_name_filter}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

data "aws_ami" "centos_app" {
  most_recent = true

  filter {
    name   = "name"
#    values = ["${var.ami_app_image_name_filter} ${var.openshift_release}"]
    values = ["${var.ami_app_image_name_filter}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

#########################################
###### Common Resources
#########################################

resource "random_string" "suffix" {
    length  = 16
    special = false
    upper   = false
}

#################################################################
## Bastion Instance
#################################################################

resource "aws_instance" "bastion" {
    ami                         = "${data.aws_ami.centos_bastion.id}"
    availability_zone           = "${local.aws_zones[0]}"
    ebs_optimized               = false
    instance_type               = "${var.aws_instance_bastion}"
    monitoring                  = true
    key_name                    = "${var.aws_key_name}"
    subnet_id                   = "${aws_subnet.public.0.id}"
    vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
    associate_public_ip_address = true
    source_dest_check           = true
    disable_api_termination     = "${var.aws_disable_api_termination}"

    root_block_device {
        volume_type           = "gp2"
        volume_size           = 100
        delete_on_termination = true
    }

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}bastion"
    }

    volume_tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}bastion"
    }
}

#################################################################
## Master Instances
#################################################################

resource "aws_instance" "masters" {
    count                       = "${var.master_count > 0 ? var.master_count : 1}"
    ami                         = "${data.aws_ami.centos_master.id}"
    availability_zone           = "${element(local.aws_zones, count.index)}"
    ebs_optimized               = false
    instance_type               = "${var.aws_instance_master}"
    iam_instance_profile        = "${aws_iam_instance_profile.master.name}"
    monitoring                  = true
    key_name                    = "${var.aws_key_name}"
    subnet_id                   = "${element(aws_subnet.private.*.id, count.index)}"
    vpc_security_group_ids      = ["${aws_security_group.master.id}", "${aws_security_group.etcd.id}", "${aws_security_group.node.id}"]
    associate_public_ip_address = false
    source_dest_check           = true
    disable_api_termination     = "${var.aws_disable_api_termination}"

    lifecycle {
        ignore_changes = [ "ebs_block_device", "tags", "volume_tags" ]
    }

    tags = {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}master-${count.index}"
        Role          = "master"
        "kubernetes.io/cluster/id" = "owned"
    }

    volume_tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}master-${count.index}"
    }
}

resource "aws_route53_record" "masters-SRV" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "masters.${var.cluster_zone}"
    type    = "SRV"
    records = ["${formatlist("1 10 9100 %s", aws_route53_record.masters.*.name)}"]
    ttl     = "300"
}


#################################################################
## Infra Instances
#################################################################

resource "aws_instance" "infras" {
    count                       = "${var.infra_count >= local.aws_zones_count ? var.infra_count : local.aws_zones_count}"
    ami                         = "${data.aws_ami.centos_infra.id}"
    availability_zone           = "${element(local.aws_zones, count.index)}"
    ebs_optimized               = false
    instance_type               = "${var.aws_instance_infra}"
    iam_instance_profile        = "${aws_iam_instance_profile.node.name}"
    monitoring                  = true
    key_name                    = "${var.aws_key_name}"
    subnet_id                   = "${element(aws_subnet.private.*.id, count.index)}"
    vpc_security_group_ids      = ["${aws_security_group.infra.id}", "${aws_security_group.node.id}"]
    associate_public_ip_address = false
    source_dest_check           = true
    disable_api_termination     = "${var.aws_disable_api_termination}"

    lifecycle {
        ignore_changes = [ "ebs_block_device", "tags", "volume_tags" ]
    }

    tags = {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}infra-${count.index}"
        Role          = "infra"
        "kubernetes.io/cluster/id" = "owned"
    }

    volume_tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}infra-${count.index}"
    }
}

resource "aws_route53_record" "infras-SRV" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "infras.${var.cluster_zone}"
    type    = "SRV"
    records = ["${formatlist("1 10 9100 %s", aws_route53_record.infras.*.name)}"]
    ttl     = "300"
}

resource "aws_route53_record" "routers-SRV" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "routers.${var.cluster_zone}"
    type    = "SRV"
    records = ["${formatlist("1 10 1936 %s", aws_route53_record.infras.*.name)}"]
    ttl     = "300"
}

#################################################################
## App Instances
#################################################################

resource "aws_instance" "apps" {
    count                       = "${var.app_count > 0 ? var.app_count : 1}"
    ami                         = "${data.aws_ami.centos_app.id}"
    availability_zone           = "${element(local.aws_zones, count.index)}"
    ebs_optimized               = false
    instance_type               = "${var.aws_instance_app}"
    iam_instance_profile        = "${aws_iam_instance_profile.node.name}"
    monitoring                  = true
    key_name                    = "${var.aws_key_name}"
    subnet_id                   = "${element(aws_subnet.private.*.id, count.index)}"
    vpc_security_group_ids      = ["${aws_security_group.node.id}"]
    associate_public_ip_address = false
    source_dest_check           = true
    disable_api_termination     = "${var.aws_disable_api_termination}"

    lifecycle {
        ignore_changes = [ "ebs_block_device", "tags", "volume_tags" ]
    }

    tags = {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}app-${count.index}"
        Role          = "app"
        "kubernetes.io/cluster/id" = "owned"
    }

    volume_tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name          = "${var.prefix}app-${count.index}"
    }
}

resource "aws_route53_record" "apps-SRV" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "apps.${var.cluster_zone}"
    type    = "SRV"
    records = ["${formatlist("1 10 9100 %s", aws_route53_record.apps.*.name)}"]
    ttl     = "300"
}

#################################################################
## ELB
#################################################################

resource "aws_elb" "api_external" {
    name                        = "${var.prefix}api-external"
    subnets                     = ["${aws_subnet.public.*.id}"]
    security_groups             = ["${aws_security_group.api_external.id}"]
    instances                   = ["${aws_instance.masters.*.id}"]
    cross_zone_load_balancing   = true
    idle_timeout                = 900
    connection_draining         = true
    connection_draining_timeout = 60
    internal                    = false

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
        ssl_certificate_id = ""
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 5
        target              = "HTTPS:443/"
        timeout             = 2
    }

#    access_logs {
#        bucket        = "${aws_s3_bucket.router-logs.id}"
#        bucket_prefix = "${var.aws_region}"
#        interval      = 60
#    }


    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}api-external"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_elb" "api_internal" {
    name                        = "${var.prefix}api-internal"
    subnets                     = ["${aws_subnet.private.*.id}"]
    security_groups             = ["${aws_security_group.api_internal.id}"]
    instances                   = ["${aws_instance.masters.*.id}"]
    cross_zone_load_balancing   = true
    idle_timeout                = 1800
    connection_draining         = true
    connection_draining_timeout = 60
    internal                    = true

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
        ssl_certificate_id = ""
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 5
        target              = "HTTPS:443/"
        timeout             = 2
    }

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}api-internal"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_elb" "infra" {
    name                        = "${var.prefix}infra"
    subnets                     = ["${aws_subnet.public.*.id}"]
    security_groups             = ["${aws_security_group.infra_elb.id}"]
    instances                   = ["${aws_instance.infras.*.id}"]
    cross_zone_load_balancing   = true
    idle_timeout                = 300
    connection_draining         = true
    connection_draining_timeout = 60
    internal                    = false

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
        ssl_certificate_id = ""
    }

    listener {
        instance_port      = 80
        instance_protocol  = "tcp"
        lb_port            = 80
        lb_protocol        = "tcp"
        ssl_certificate_id = ""
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 5
        target              = "SSL:443"
        timeout             = 2
    }

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}infra"
        "kubernetes.io/cluster/id" = "owned"
    }
}

#################################################################
## IAM
#################################################################

resource "aws_iam_instance_profile" "master" {
    name  = "${var.prefix}master"
    path  = "/"
    role = "${aws_iam_role.master.name}"
}

resource "aws_iam_role" "master" {
    name               = "${var.prefix}master"
    path               = "/"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "master" {
    name   = "${var.prefix}master"
    role   = "${aws_iam_role.master.name}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

#---------------------------------------------------------------#

resource "aws_iam_instance_profile" "node" {
    name  = "${var.prefix}node"
    path  = "/"
    role = "${aws_iam_role.node.name}"
}


resource "aws_iam_role" "node" {
    name               = "${var.prefix}node"
    path               = "/"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "node" {
    name   = "${var.prefix}node"
    role   = "${aws_iam_role.node.name}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*",
        "ec2:AttachVolume",
        "ec2:DetachVolume"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

#---------------------------------------------------------------#

resource "aws_iam_user" "openshift-registry" {
    name = "${var.prefix}openshift-registry"
    path = "/"
}

resource "aws_iam_user_policy" "registry-all-s3" {
    name   = "all-s3"
    user   = "${aws_iam_user.openshift-registry.name}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_access_key" "openshift-registry" {
  user    = "${aws_iam_user.openshift-registry.name}"
}

resource "aws_s3_bucket" "openshift-registry" {
    bucket = "${local.aws_bucket_name}"
    acl    = "private"
    force_destroy = true

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}openshift-registry"
    }
}

#---------------------------------------------------------------#

#resource "aws_s3_bucket" "router-logs" {
#    bucket = "${var.prefix}router-logs"
#    acl    = "private"
#    policy = <<POLICY
#{
#    "Version": "2012-10-17",
#    "Id": "AWSConsole-AccessLogs-Policy-1506528020158",
#    "Statement": [
#        {
#            "Sid": "AWSConsoleStmt-1506528020158",
#            "Effect": "Allow",
#            "Principal": {
#                "AWS": "arn:aws:iam::127311923021:root"
#            },
#            "Action": "s3:PutObject",
#            "Resource": "arn:aws:s3:::${var.prefix}router-logs/${var.aws_region}/AWSLogs/*"
#        }
#    ]
#}
#POLICY
#
#    tags {
#        ResourceGroup = "${var.aws_resource_group}"
#        Name = "${var.prefix}router-logs"
#    }
#}

#################################################################
## DNS
#################################################################

data "aws_route53_zone" "apps" {
    zone_id = "${var.apps_zone_id}"

#    tags {
#        ResourceGroup = "${var.aws_resource_group}"
#        Name = "${var.prefix}apps"
#    }
}

resource "aws_route53_record" "infra-apps-A" {
    zone_id = "${data.aws_route53_zone.apps.id}"
    name    = "infra.${var.apps_zone}"
    type    = "A"

    alias {
        name    = "${aws_elb.infra.dns_name}"
        zone_id = "${aws_elb.infra.zone_id}"
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "infra-apps-wildcard" {
    zone_id = "${data.aws_route53_zone.apps.id}"
    name    = "*.${var.apps_zone}"
    type    = "A"

    alias {
        name    = "${aws_elb.infra.dns_name}"
        zone_id = "${aws_elb.infra.zone_id}"
        evaluate_target_health = false
    }
}

#---------------------------------------------------------------#

data "aws_route53_zone" "cluster" {
    zone_id = "${var.cluster_zone_id}"
}

resource "aws_route53_record" "bastion-A" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "bastion.${var.cluster_zone}"
    type    = "A"
    records = ["${aws_eip.bastion.public_ip}"]
    ttl     = "300"
}

resource "aws_route53_record" "api-CNAME" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "api.${var.cluster_zone}"
    type    = "CNAME"
    records = ["${aws_elb.api_external.dns_name}"]
    ttl     = "300"
}

resource "aws_route53_record" "api_internal-CNAME" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "api-internal"
    type    = "CNAME"
    records = ["${aws_elb.api_internal.dns_name}"]
    ttl     = "300"
}

resource "aws_route53_record" "portal-CNAME" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "portal.${var.cluster_zone}"
    type    = "CNAME"
    records = ["${aws_elb.infra.dns_name}"]
    ttl     = "300"
}

resource "aws_route53_record" "gapi-CNAME" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "gapi.${var.cluster_zone}"
    type    = "CNAME"
    records = ["${aws_elb.infra.dns_name}"]
    ttl     = "300"
}

resource "aws_route53_record" "usage-CNAME" {
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "usage.${var.cluster_zone}"
    type    = "CNAME"
    records = ["${aws_elb.infra.dns_name}"]
    ttl     = "300"
}

resource "aws_route53_record" "masters" {
    count = "${aws_instance.masters.count}"
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "master-${count.index + 1}.${var.cluster_zone}"
    type    = "A"
    records = ["${element(aws_instance.masters.*.private_ip, count.index)}"]
    ttl     = "300"
}

resource "aws_route53_record" "infras" {
    count = "${aws_instance.infras.count}"
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "infra-${count.index + 1}.${var.cluster_zone}"
    type    = "A"
    records = ["${element(aws_instance.infras.*.private_ip, count.index)}"]
    ttl     = "300"
}

resource "aws_route53_record" "apps" {
    count = "${aws_instance.apps.count}"
    zone_id = "${data.aws_route53_zone.cluster.id}"
    name    = "app-${count.index + 1}.${var.cluster_zone}"
    type    = "A"
    records = ["${element(aws_instance.apps.*.private_ip, count.index)}"]
    ttl     = "300"
}

#################################################################
## Security Groups
#################################################################

resource "aws_security_group" "bastion" {
    name        = "${var.prefix}bastion"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}bastion"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "bastion_22" {
    type            = "ingress"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion_egress_0" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.bastion.id}"
}

#---------------------------------------------------------------#

resource "aws_security_group" "master" {
    name        = "${var.prefix}master"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}master"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "master_master_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "master_api_internal_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.api_internal.id}"
}

resource "aws_security_group_rule" "master_api_external_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.api_external.id}"
}

resource "aws_security_group_rule" "master_node_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "master_node_8054" {
    type            = "ingress"
    from_port       = 8054
    to_port         = 8054
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "master_node_24224" {
    type            = "ingress"
    from_port       = 24224
    to_port         = 24224
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "master_node_8053" {
    type            = "ingress"
    from_port       = 8053
    to_port         = 8053
    protocol        = "udp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "master_node_24224_udp" {
    type            = "ingress"
    from_port       = 24224
    to_port         = 24224
    protocol        = "udp"
    security_group_id        = "${aws_security_group.master.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "master_egress_0" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_group_id   = "${aws_security_group.master.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

#---------------------------------------------------------------#

resource "aws_security_group" "etcd" {
    name        = "${var.prefix}etcd"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}etcd"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "etcd_etcd_2379" {
    type            = "ingress"
    from_port       = 2379
    to_port         = 2379
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.etcd.id}"
    source_security_group_id = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "etcd_master_2379" {
    type            = "ingress"
    from_port       = 2379
    to_port         = 2379
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.etcd.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "etcd_etcd_2380" {
    type            = "ingress"
    from_port       = 2380
    to_port         = 2380
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.etcd.id}"
    source_security_group_id = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "etcd_egress_0" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_group_id   = "${aws_security_group.etcd.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

#---------------------------------------------------------------#

resource "aws_security_group" "infra" {
    name        = "${var.prefix}infra"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}infra"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "infra_infra_elb_80" {
    type            = "ingress"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.infra_elb.id}"
}

resource "aws_security_group_rule" "infra_infra_elb_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.infra_elb.id}"
}

resource "aws_security_group_rule" "infra_egress_0" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_group_id   = "${aws_security_group.infra.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node_infra_prometheus_haproxy_1936" {
    type            = "ingress"
    from_port       = 1936
    to_port         = 1936
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "infra_infra_prometheus_haproxy_1936" {
    type            = "ingress"
    from_port       = 1936
    to_port         = 1936
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.infra.id}"
}

resource "aws_security_group_rule" "master_infra_crio_10010" {
    type            = "ingress"
    from_port       = 10010
    to_port         = 10010
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

#---------------------------------------------------------------#

resource "aws_security_group" "infra_elb" {
    name        = "${var.prefix}infra-elb"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}infra-elb"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "infra_elb_80" {
    type            = "ingress"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_group_id   = "${aws_security_group.infra_elb.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "infra_elb_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id   = "${aws_security_group.infra_elb.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "infra_elb_infra_egress_80" {
    type            = "egress"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_group_id           = "${aws_security_group.infra_elb.id}"
    source_security_group_id    = "${aws_security_group.infra.id}"
}

resource "aws_security_group_rule" "infra_elb_infra_egress_443" {
    type            = "egress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id           = "${aws_security_group.infra_elb.id}"
    source_security_group_id    = "${aws_security_group.infra.id}"
}

#---------------------------------------------------------------#

resource "aws_security_group" "node" {
    name        = "${var.prefix}node"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}node"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "node_bastion_22" {
    type            = "ingress"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "node_master_10250" {
    type            = "ingress"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "node_node_10250" {
    type            = "ingress"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "node_node_4789" {
    type            = "ingress"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "node_egress_0" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_group_id        = "${aws_security_group.node.id}"
    cidr_blocks     = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node_prometheus_node_exporter_9100" {
    type            = "ingress"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "infra_node_prometheus_node_exporter_9100" {
    type            = "ingress"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.infra.id}"
    source_security_group_id = "${aws_security_group.infra.id}"
}

resource "aws_security_group_rule" "master_node_crio_10010" {
    type            = "ingress"
    from_port       = 10010
    to_port         = 10010
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

#---------------------------------------------------------------#

resource "aws_security_group" "api_internal" {
    name        = "${var.prefix}api-internal"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}api-internal"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "api_internal_master_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_internal.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "api_internal_node_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_internal.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}

resource "aws_security_group_rule" "api_internal_bastion_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_internal.id}"
    source_security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "api_internal_master_egress_443" {
    type            = "egress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_internal.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

#---------------------------------------------------------------#

resource "aws_security_group" "api_external" {
    name        = "${var.prefix}api-external"
    vpc_id      = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}api-external"
        "kubernetes.io/cluster/id" = "owned"
    }
}

resource "aws_security_group_rule" "api_external_80" {
    type            = "ingress"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_group_id   = "${aws_security_group.api_external.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "api_external_443" {
    type            = "ingress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id   = "${aws_security_group.api_external.id}"
    cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "api_external_egress_80" {
    type            = "egress"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_external.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

resource "aws_security_group_rule" "api_external_egress_443" {
    type            = "egress"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.api_external.id}"
    source_security_group_id = "${aws_security_group.master.id}"
}

#################################################################
## Networking
#################################################################

resource "aws_vpc_dhcp_options" "dhcp_opts" {
  domain_name          = "${var.aws_region}.compute.internal"
  domain_name_servers  = ["AmazonProvidedDNS"]

  tags {
      ResourceGroup = "${var.aws_resource_group}"
      Name = "${var.prefix}dhcp-opts"
  }
}

resource "aws_vpc_dhcp_options_association" "dhcp_opts_assoc" {
  vpc_id          = "${aws_vpc.openshift.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_opts.id}"
}

#---------------------------------------------------------------#

resource "aws_eip" "nat_gateway" {
    vpc = true
}

resource "aws_eip" "bastion" {
    instance = "${aws_instance.bastion.id}"
    vpc      = true
}

#---------------------------------------------------------------#

resource "aws_internet_gateway" "internet" {
    vpc_id = "${aws_vpc.openshift.id}"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}internet-gateway"
    }
}

resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.nat_gateway.id}"
    subnet_id     = "${aws_subnet.public.0.id}"
}

#---------------------------------------------------------------#

resource "aws_route_table_association" "vpc_public" {
    count = "${local.aws_zones_count}"
    route_table_id = "${aws_route_table.vpc.id}"
    subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
}

resource "aws_route_table_association" "internal_private" {
    count = "${local.aws_zones_count}"
    route_table_id = "${aws_route_table.internal.id}"
    subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
}

#---------------------------------------------------------------#

resource "aws_route_table" "vpc" {
    vpc_id     = "${aws_vpc.openshift.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.internet.id}"
    }

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}vpc"
    }
}

resource "aws_route_table" "internal" {
    vpc_id     = "${aws_vpc.openshift.id}"

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.nat.id}"
    }

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}internal"
    }
}

#---------------------------------------------------------------#

resource "aws_subnet" "private" {
    count                   = "${local.aws_zones_count}"
    vpc_id                  = "${aws_vpc.openshift.id}"
    cidr_block              = "${cidrsubnet("10.0.0.0/16", local.aws_zones_count, count.index)}"
    availability_zone       = "${element(local.aws_zones, count.index)}"
    map_public_ip_on_launch = false

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}private-${count.index}"
    }
}

resource "aws_subnet" "public" {
    count                   = "${local.aws_zones_count}"
    vpc_id                  = "${aws_vpc.openshift.id}"
    cidr_block              = "${cidrsubnet("10.0.0.0/16", local.aws_zones_count, count.index + local.aws_zones_count)}"
    availability_zone       = "${element(local.aws_zones, count.index)}"
    map_public_ip_on_launch = true

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}public-${count.index}"
    }
}

#---------------------------------------------------------------#

resource "aws_vpc" "openshift" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${var.prefix}openshift"
    }
}

#################################################################
## Outputs
#################################################################

output "CLUSTER_ZONE" {
    value = "${var.cluster_zone}"
}

output "APPS_ZONE" {
    value = "${var.apps_zone}"
}

output "AWS_DEFAULT_REGION" {
    value = "${var.aws_region}"
}

output "CLUSTER_REGION" {
    value = "${var.aws_region}"
}

output "DEFAULT_USER" {
    value = "${var.user}"
}

output "CLUSTER_ID" {
    value = "${var.cluster_id}"
}

# Endpoints
###########

output "API_ENDPOINT" {
    value = "${aws_route53_record.api-CNAME.fqdn}"
}

output "API_ENDPOINT_INTERNAL" {
    value = "${aws_route53_record.api_internal-CNAME.fqdn}"
}

output "PORTAL_ENDPOINT" {
    value = "${aws_route53_record.portal-CNAME.fqdn}"
}

output "GAPI_ENDPOINT" {
    value = "${aws_route53_record.gapi-CNAME.fqdn}"
}

output "USAGE_ENDPOINT" {
    value = "${aws_route53_record.usage-CNAME.fqdn}"
}

output "INFRA_ENDPOINT" {
    value = "${aws_elb.infra.dns_name}"
}

output "BASTION_ENDPOINT" {
    value = "bastion.${var.cluster_zone}"
}

output "MASTER_HOSTNAMES" {
    value = "${aws_instance.masters.*.private_dns}"
}

output "INFRA_HOSTNAMES" {
    value = "${aws_instance.infras.*.private_dns}"
}

output "APP_HOSTNAMES" {
    value = "${aws_instance.apps.*.private_dns}"
}


# Registry
##########

output "REGISTRY_STORAGE_PROVIDER" {
    value = "s3"
}

output "REGISTRY_AWS_BUCKET_NAME" {
    value = "${aws_s3_bucket.openshift-registry.id}"
}

output "REGISTRY_AWS_REGION" {
    value = "${aws_s3_bucket.openshift-registry.region}"
}

output "REGISTRY_AWS_ACCESS_KEY_ID" {
    value = "${aws_iam_access_key.openshift-registry.id}"
}

output "REGISTRY_AWS_SECRET_ACCESS_KEY" {
    value = "${aws_iam_access_key.openshift-registry.secret}"
}
