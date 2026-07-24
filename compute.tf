resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo systemctl start nginx
              cd /home/ec2-user/E-commerce
      	      sudo -u ec2-user git pull origin main

              export NVM_DIR="/home/ec2-user/.nvm"
              [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

              DB_URL=$(aws ssm get-parameter 
		--name "${var.ssm_parameter_name}" 
		--with-decryption 
		--query "Parameter.Value" 
		--output text 
		--region ${var.aws_region})

		cat > apps/storefront/.env.production <<EOT 
		DATABASE_URL="$DB_URL" 				
		NODE_ENV="production" 
		NEXTAUTH_URL="https://e-commerce.mavencrest.site" 						NEXTAUTH_SECRET="svB5kC5z06f0SegSPv5mGq+FARrd6NjSi8d0Ugp+ghM=" 
		EOT

		cat > apps/admin/.env.production <<EOT
		DATABASE_URL="$DB_URL"
		NODE_ENV="production"
		EOT
	      
	      nnpm ci  
	      npm run build:storefront
	      npm run build:admin

              pm2 delete all || true

		pm2 start npm \
  		--name "mavencrest-storefront" \
 		 -- run start:storefront

		pm2 start npm \
  		--name "mavencrest-admin" \
 		 -- run start:admin

		pm2 save
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.project_name}-${var.environment}-asg"
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project_name}-${var.environment}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_utilization
  }
}

# Outputs
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public URL to access the application load balancer"
}
