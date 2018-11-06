resource "aws_security_group_rule" "node_node_all" {
    type            = "ingress"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_group_id        = "${aws_security_group.node.id}"
    source_security_group_id = "${aws_security_group.node.id}"
}
