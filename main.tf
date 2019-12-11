locals {
  name_prefix = "${var.name_prefix}-${var.load_balancer_type == "network" ? "nlb" : "alb"}"
}

resource "aws_lb" "main" {
  name = local.name_prefix

  load_balancer_type = var.load_balancer_type
  internal           = var.internal
  subnets            = var.subnets
  security_groups    = aws_security_group.main.*.id

  idle_timeout                     = var.idle_timeout
  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_http2                     = var.enable_http2
  ip_address_type                  = var.ip_address_type

  dynamic "access_logs" {
    for_each = length(keys(var.access_logs)) == 0 ? [] : [var.access_logs]

    content {
      enabled = lookup(access_logs.value, "enabled", lookup(access_logs.value, "bucket", null) != null)
      bucket  = lookup(access_logs.value, "bucket", null)
      prefix  = lookup(access_logs.value, "prefix", null)
    }
  }

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping

    content {
      subnet_id     = subnet_mapping.value.subnet_id
      allocation_id = lookup(subnet_mapping.value, "allocation_id", null)
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = local.name_prefix
    },
  )

  timeouts {
    create = var.load_balancer_create_timeout
    update = var.load_balancer_update_timeout
    delete = var.load_balancer_delete_timeout
  }
}

resource "aws_security_group" "main" {
  count       = var.load_balancer_type == "network" ? 0 : 1
  name        = "${local.name_prefix}-sg"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = "${local.name_prefix}-sg"
    },
  )
}

resource "aws_security_group_rule" "egress" {
  count             = var.load_balancer_type == "network" ? 0 : 1
  security_group_id = aws_security_group.main[0].id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}