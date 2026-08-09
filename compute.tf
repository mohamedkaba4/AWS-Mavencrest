resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = data.aws_ssm_parameter.mavencrest_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-USER_DATA
#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/mavencrest-user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

APP_DIR="/home/ec2-user/E-commerce"
AWS_REGION="us-east-1"

# Start Nginx
systemctl enable nginx
systemctl start nginx

# Retrieve runtime secrets
DB_URL=$(aws ssm get-parameter \
  --name "/nextjs/prod/DATABASE_URL" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION")

NEXTAUTH_SECRET=$(aws ssm get-parameter \
  --name "/nextjs/prod/NEXTAUTH_SECRET" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION")

# Create runtime environment files
cat > "$APP_DIR/apps/storefront/.env.production" <<STOREFRONT_ENV
DATABASE_URL="$DB_URL"
NODE_ENV="production"
NEXTAUTH_URL="https://store.mavencrest.site"
NEXTAUTH_SECRET="$NEXTAUTH_SECRET"
STOREFRONT_ENV

cat > "$APP_DIR/apps/admin/.env.production" <<ADMIN_ENV
DATABASE_URL="$DB_URL"
NODE_ENV="production"
ADMIN_ENV

chown ec2-user:ec2-user \
  "$APP_DIR/apps/storefront/.env.production" \
  "$APP_DIR/apps/admin/.env.production"

# Restore the PM2 processes baked into the AMI
sudo -iu ec2-user bash <<'DEPLOY_SCRIPT'
set -euo pipefail

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

cd /home/ec2-user/E-commerce

pm2 resurrect
DEPLOY_SCRIPT

USER_DATA
  )
}

resource "aws_autoscaling_group" "app_asg" {
  name             = "${var.project_name}-${var.environment}-asg"
  desired_capacity = var.asg_desired_capacity
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  target_group_arns = [aws_lb_target_group.app_tg.arn,
    aws_lb_target_group.admin_tg.arn
  ]
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
  strategy = "Rolling"

  preferences {
    min_healthy_percentage = 50
    instance_warmup        = 300
  }
  
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

data "aws_ssm_parameter" "mavencrest_ami" {
  name = "/mavencrest/prod/ami-id"
}

# Outputs
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public URL to access the application load balancer"
}
