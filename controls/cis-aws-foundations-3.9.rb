# encoding: UTF-8

control "3.9" do
  title "Ensure a log metric filter and alarm exist for AWS Config configuration changes"
  desc  "Real-time monitoring of API calls can be achieved by directing CloudTrail Logs to CloudWatch Logs and establishing corresponding metric filters and alarms. It is recommended that a metric filter and alarm be established for detecting changes to CloudTrail's configurations."
  desc  "rationale", "Monitoring changes to AWS Config configuration will help ensure sustained visibility of configuration items within the AWS account."
  desc  "check", "Perform the following to ensure that there is at least one active multi-region CloudTrail with prescribed metric filters and alarms configured:

    1. Identify the log group name configured for use with active multi-region CloudTrail:

    - List all CloudTrails:

    `aws cloudtrail describe-trails`

    - Identify Multi region Cloudtrails: `Trails with \"IsMultiRegionTrail\" set to true`

    - From value associated with CloudWatchLogsLogGroupArn note ``

    Example: for CloudWatchLogsLogGroupArn that looks like `arn:aws:logs:::log-group:NewGroup:*`, `` would be `NewGroup`

    - Ensure Identified Multi region CloudTrail is active

    `aws cloudtrail get-trail-status --name `

    ensure `IsLogging` is set to `TRUE`

    - Ensure identified Multi-region Cloudtrail captures all Management Events

    `aws cloudtrail get-event-selectors --trail-name
    `

    Ensure there is at least one Event Selector for a Trail with `IncludeManagementEvents` set to `true` and `ReadWriteType` set to `All`

    2. Get a list of all associated metric filters for this ``:
    ```
    aws logs describe-metric-filters --log-group-name \"\"
    ```
    3. Ensure the output from the above command contains the following:
    ```
    \"filterPattern\": \"{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder)) }\"
    ```
    4. Note the `` value associated with the `filterPattern` found in step 3.

    5. Get a list of CloudWatch alarms and filter on the `` captured in step 4.
    ```
    aws cloudwatch describe-alarms --query 'MetricAlarms[?MetricName== ``]'
    ```
    6. Note the `AlarmActions` value - this will provide the SNS topic ARN value.

    7. Ensure there is at least one active subscriber to the SNS topic
    ```
    aws sns list-subscriptions-by-topic --topic-arn
    ```
    at least one subscription should have \"SubscriptionArn\" with valid aws ARN.
    ```
    Example of valid \"SubscriptionArn\": \"arn:aws:sns::::\"
    ```"
  desc  "fix", "Perform the following to setup the metric filter, alarm, SNS topic, and subscription:

    1. Create a metric filter based on filter pattern provided which checks for AWS Configuration changes and the `` taken from audit step 1.
    ```
    aws logs put-metric-filter --log-group-name  --filter-name `` --metric-transformations metricName= `` ,metricNamespace='CISBenchmark',metricValue=1 --filter-pattern '{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder)) }'
    ```

    **Note**: You can choose your own metricName and metricNamespace strings. Using the same metricNamespace for all Foundations Benchmark metrics will group them together.

    2. Create an SNS topic that the alarm will notify
    ```
    aws sns create-topic --name
    ```

    **Note**: you can execute this command once and then re-use the same topic for all monitoring alarms.

    3. Create an SNS subscription to topic created in step 2
    ```
    aws sns subscribe --topic-arn  --protocol

    \t --notification-endpoint
    ```

    **Note**: you can execute this command once and then re-use the SNS subscription for all monitoring alarms.

    4. Create an alarm that is associated with the CloudWatch Logs Metric Filter created in step 1 and an SNS topic created in step 2
    ```
    aws cloudwatch put-metric-alarm --alarm-name `` --metric-name `` --statistic Sum --period 300 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 1 --namespace 'CISBenchmark' --alarm-actions
    ```"
  impact 0.5
  tag severity: "Medium"
  tag gtitle: nil
  tag gid: nil
  tag rid: nil
  tag stig_id: nil
  tag fix_id: nil
  tag cci: nil
  tag nist: nil
  tag notes: nil
  tag comment: nil
  tag cis_controls: "TITLE:Maintain Detailed Asset Inventory CONTROL:1.4 DESCRIPTION:Maintain an accurate and up-to-date inventory of all technology assets with the potential to store or process information. This inventory shall include all hardware assets, whether connected to the organization's network or not.;TITLE:Document Traffic Configuration Rules CONTROL:11.2 DESCRIPTION:All configuration rules that allow traffic to flow through network devices should be documented in a configuration management system with a specific business reason for each rule, a specific individual\x92s name responsible for that business need, and an expected duration of the need.;TITLE:Maintain an Inventory of Authentication Systems CONTROL:16.1 DESCRIPTION:Maintain an inventory of each of the organization's authentication systems, including those located onsite or at a remote service provider.;"
  tag ref: "CIS CSC v6.0 #5.4:https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html:https://docs.aws.amazon.com/awscloudtrail/latest/userguide/receive-cloudtrail-log-files-from-multiple-regions.html:https://docs.aws.amazon.com/sns/latest/dg/SubscribeTopic.html"

  unless ENV['AWS_REGION'].eql?(attribute('default_aws_region'))
    impact 0.0
    desc  "Currently inspected region #{ENV['AWS_REGION']} is not the primary AWS region"
  end

  describe aws_cloudtrail_trails do
    it { should exist }
  end

  describe.one do
    aws_cloudtrail_trails.trail_arns.each do |trail|

      describe aws_cloudtrail_trail(trail) do
        its ('cloud_watch_logs_log_group_arn') { should_not be_nil }
      end

      trail_log_group_name = aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.scan(/log-group:(.+):/).last.first unless aws_cloudtrail_trail(trail).cloud_watch_logs_log_group_arn.nil?

      next if trail_log_group_name.nil?

      pattern = '{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder))}'

      describe aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name) do
        it { should exist }
      end

      metric_name = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_name
      metric_namespace = aws_cloudwatch_log_metric_filter(pattern: pattern, log_group_name: trail_log_group_name).metric_namespace
      next if metric_name.nil? && metric_namespace.nil?

      describe aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ) do
        it { should exist }
        its ('alarm_actions') { should_not be_empty }
      end

      aws_cloudwatch_alarm(
        metric_name: metric_name,
        metric_namespace: metric_namespace
      ).alarm_actions.each do |sns|
        describe aws_sns_topic(sns) do
          it { should exist }
          its('confirmed_subscription_count') { should_not be_zero }
        end
      end
    end
  end
end

