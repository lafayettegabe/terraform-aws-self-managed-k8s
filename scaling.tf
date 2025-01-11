resource "aws_autoscaling_policy" "k8s_worker_scale_up" {
  name                   = "k8s_worker-scale-up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.k8s_worker_asg.name
}

resource "aws_autoscaling_policy" "k8s_worker_scale_down" {
  name                   = "k8s_worker-scale-down"
  scaling_adjustment     = -2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.k8s_worker_asg.name
}

resource "aws_cloudwatch_metric_alarm" "k8s_worker_cpu_high" {
  alarm_name          = "k8s_worker-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "30"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Scale up if CPU > 80% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.k8s_worker_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.k8s_worker_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s_worker_cpu_low" {
  alarm_name          = "k8s_worker-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "30"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "Scale down if CPU < 20% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.k8s_worker_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.k8s_worker_asg.name
  }
}
