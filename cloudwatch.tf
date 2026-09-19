# Storefront target group health alarm
resource "aws_cloudwatch_metric_alarm" "storefront_unhealthy_targets" {
  alarm_name        = "${var.project_name}-${var.environment}-storefront-unhealthy-targets"
  alarm_description = "Triggers when one or more storefront targets are unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Minimum"
  period    = 30

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}


# Admin target group health alarm
resource "aws_cloudwatch_metric_alarm" "admin_unhealthy_targets" {
  alarm_name        = "${var.project_name}-${var.environment}-admin-unhealthy-targets"
  alarm_description = "Triggers when one or more admin targets are unhealthy"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Minimum"
  period    = 30

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  treat_missing_data = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.admin_tg.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}