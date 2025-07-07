resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.joindevops.id   # Gold copy of AMI
  vpc_security_group_ids = [data.aws_ssm_parameter.frontend_sg_id.value]
  instance_type          = "t3.micro"
  subnet_id              = local.public_subnet_id
  tags = merge(
    var.common_tags,
    {
      Name = "/${var.project_name}/${var.environment}-frontend"
    }
  )
}

# resource "aws_instance" "cluster" {
#   count = 3

#   # ...
# }

# The primary use-case for the null resource is as a do-nothing container
# for arbitrary actions taken by a provisioner.
#
# In this example, three EC2 instances are created and then a
# null_resource instance is used to gather data about all three
# and execute a single action that affects them all. Due to the triggers
# map, the null_resource will be replaced each time the instance ids
# change, and thus the remote-exec provisioner will be re-run.
resource "null_resource" "frontend" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = aws_instance.frontend.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host     = aws_instance.frontend.public_ip
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "frontend.sh"
    destination = "/tmp/frontend.sh"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with public_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/frontend.sh",
      "sudo sh /tmp/frontend.sh ${var.environment}"
    ]
  }
}

resource "aws_ec2_instance_state" "frontend" {
  instance_id = aws_instance.frontend.id
  state       = "stopped"
  depends_on  = [null_resource.frontend]
}

resource "aws_ami_from_instance" "frontend" {
  name               = local.resource_name
  source_instance_id = aws_instance.frontend.id
  depends_on         = [aws_ec2_instance_state.frontend]
}

resource "null_resource" "frontend_delete" {

  triggers = {
    instance_id = aws_instance.frontend.id
  }

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.frontend.id}"
  }
  depends_on = [aws_ami_from_instance.frontend]
}

resource "aws_lb_target_group" "frontend" {
  name     = local.resource_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    protocol            = "HTTP"
    port                = 80
    path                = "/"
    matcher             = "200-299"
    interval            = 10
  }
}

resource "aws_launch_template" "frontend" {
  name     = local.resource_name
  image_id = aws_ami_from_instance.frontend.id

  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.micro"
  update_default_version               = true

  vpc_security_group_ids = [local.frontend_sg_id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name
    }
  }
}

resource "aws_autoscaling_group" "frontend" {
  name                      = local.resource_name
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 1
  target_group_arns = [aws_lb_target_group.frontend.arn]
  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }
  vpc_zone_identifier = local.public_subnet_ids
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["aws_launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "local.resource_name"
    propagate_at_launch = true
  }

  timeouts {
    delete = "5m"
  }

  tag {
    key                 = "Project"
    value               = "expense"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = "dev"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "frontend" {
  name                   = "${local.resource_name}-frontend"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }

}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = data.aws_ssm_parameter.web_alb_listener_arn.value
  priority = 10
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    host_header {
      values = ["expense-${var.environment}.${var.domain_name}"]
    }
  }
}

