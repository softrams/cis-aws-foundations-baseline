# encoding: UTF-8

control "3.13" do
  title "Ensure a log metric filter and alarm exist for route table changes"
  desc  "Real-time monitoring of API calls can be achieved by directing
CloudTrail Logs to CloudWatch Logs and establishing corresponding metric
filters and alarms. Routing tables are used to route network traffic between
subnets and to network gateways. It is recommended that a metric filter and
alarm be established for changes to route tables."
  desc  "rationale", "Monitoring changes to route tables will help ensure that
all VPC traffic flows through an expected path."
  desc  "check", "
    Perform the following to ensure that there is at least one active
multi-region CloudTrail with prescribed metric filters and alarms configured:

    1. Identify the log group name configured for use with active multi-region
CloudTrail:

    - List all CloudTrails:

    `aws cloudtrail describe-trails`

    - Identify Multi region Cloudtrails: `Trails with \"IsMultiRegionTrail\"
set to true`

    - From value associated with CloudWatchLogsLogGroupArn note ``

    Example: for CloudWatchLogsLogGroupArn that looks like
`arn:aws:logs:::log-group:NewGroup:*`, `` would be `NewGroup`

    - Ensure Identified Multi region CloudTrail is active

    `aws cloudtrail get-trail-status --name `

    ensure `IsLogging` is set to `TRUE`

    - Ensure identified Multi-region Cloudtrail captures all Management Events

    `aws cloudtrail get-event-selectors --trail-name
    `

    Ensure there is at least one Event Selector for a Trail with
`IncludeManagementEvents` set to `true` and `ReadWriteType` set to `All`

    2. Get a list of all associated metric filters for this ``:

    ```
    aws logs describe-metric-filters --log-group-name \"\"
    ```

    3. Ensure the output from the above command contains the following:

    ```
    \"filterPattern\": \"{ ($.eventName = CreateRoute) || ($.eventName =
CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName =
ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) ||
($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }\"
    ```

    4. Note the `` value associated with the `filterPattern` found in step 3.

    5. Get a list of CloudWatch alarms and filter on the `` captured in step 4.

    ```
    aws cloudwatch describe-alarms --query 'MetricAlarms[?MetricName== ``]'
    ```

    6. Note the `AlarmActions` value - this will provide the SNS topic ARN
value.

    7. Ensure there is at least one active subscriber to the SNS topic

    ```
    aws sns list-subscriptions-by-topic --topic-arn
    ```
    at least one subscription should have \"SubscriptionArn\" with valid aws
ARN.

    ```
    Example of valid \"SubscriptionArn\": \"arn:aws:sns::::\"
    ```
  "
  desc  "fix", "
    Perform the following to setup the metric filter, alarm, SNS topic, and
subscription:

    1. Create a metric filter based on filter pattern provided which checks for
route table changes and the `` taken from audit step 1.
    ```
    aws logs put-metric-filter --log-group-name  --filter-name ``
--metric-transformations metricName= ``
,metricNamespace='CISBenchmark',metricValue=1 --filter-pattern '{ ($.eventName
= CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName =
ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName =
DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName =
DisassociateRouteTable) }'
    ```

    **Note**: You can choose your own metricName and metricNamespace strings.
Using the same metricNamespace for all Foundations Benchmark metrics will group
them together.

    2. Create an SNS topic that the alarm will notify
    ```
    aws sns create-topic --name
    ```

    **Note**: you can execute this command once and then re-use the same topic
for all monitoring alarms.

    3. Create an SNS subscription to the topic created in step 2
    ```
    aws sns subscribe --topic-arn  --protocol

    \t --notification-endpoint
    ```

    **Note**: you can execute this command once and then re-use the SNS
subscription for all monitoring alarms.

    4. Create an alarm that is associated with the CloudWatch Logs Metric
Filter created in step 1 and an SNS topic created in step 2
    ```
    aws cloudwatch put-metric-alarm --alarm-name `` --metric-name ``
--statistic Sum --period 300 --threshold 1 --comparison-operator
GreaterThanOrEqualToThreshold --evaluation-periods 1 --namespace 'CISBenchmark'
--alarm-actions
    ```
  "
  impact 0.3
  tag severity: "Low"
  tag gtitle: nil
  tag gid: nil
  tag rid: nil
  tag stig_id: nil
  tag fix_id: nil
  tag cci: nil
  tag nist: nil
  tag cis_controls: "TITLE:Use Automated Tools to Verify Standard Device
Configurations and Detect Changes CONTROL:11.3 DESCRIPTION:Compare all network
device configuration against approved security configurations defined for each
network device in use and alert when any deviations are
discovered.;TITLE:Activate audit logging CONTROL:6.2 DESCRIPTION:Ensure that
local logging has been enabled on all systems and networking devices.;"
  tag ref:
"https://docs.aws.amazon.com/awscloudtrail/latest/userguide/receive-cloudtrail-log-files-from-multiple-regions.html:https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html:https://docs.aws.amazon.com/sns/latest/dg/SubscribeTopic.html"
end

