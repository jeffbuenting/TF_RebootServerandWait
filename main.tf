terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ssm_document" "RebootServerandWait" {
  name            = "RebootServerandWait"
  document_format = "YAML"
  document_type   = "Automation"

  content = <<DOC
# https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-authoring-runbooks.html#automation-authoring-runbooks-environment

# runbook to reboot and wait for Server to come back online.  then wait x number of minutes before continuing
# Note: all servers were patched in previous maintenance task with NoReboot Option

# gather parameters for the rest of the runbook
description: 'An example of an Automation runbook that patches groups of Amazon EC2 instances in stages.'
schemaVersion: '0.3'
assumeRole: '{{AutomationAssumeRole}}'
parameters:
  # AutomationAssumeRole:
  #   type: String
  #   description: '(Required) The Amazon Resource Name (ARN) of the IAM role that allows Automation to perform the actions on your behalf. If no role is specified, Systems Manager Automation uses your IAM permissions to operate this runbook.'
  SleepDuration:
    type: String
    description: "(Required) ISO xxxxxx time format for the duration of time to wait."
    default: 'PT20M'
  InstanceId:
    type: String
    description: '(Required) Instance ID of the EC2 Instance to reboot.'

mainSteps:
  # Reboot Server
  - name: RebootServer
    # action: 'aws:runCommand'
    action: 'aws:executeAutomation'
    onFailure: Abort
    timeoutSeconds: 5400
    inputs:
      DocumentName: 'AWS-RestartEC2Instance'
      RuntimeParameters:
        InstanceId: 
          - '{{InstanceId}}'
        # AutomationAssumeRole: '{{AutomationAssumeRole}}'

  # wait for Server to reboot an reach running state
  - name: verifyInstanceStopped
    action: 'aws:waitForAwsResourceProperty'
    timeoutSeconds: 120
    inputs:
      Service: ec2
      Api: DescribeInstances
      InstanceIds:
        - '{{InstanceId}}'
      PropertySelector: '$.Reservations[0].Instances[0].State.Name'
      DesiredValues:
        - stopped
  - name: verifyInstanceRunning
    action: 'aws:waitForAwsResourceProperty'
    timeoutSeconds: 120
    inputs:
      Service: ec2
      Api: DescribeInstances
      InstanceIds:
        - '{{InstanceId}}'
      PropertySelector: '$.Reservations[0].Instances[0].State.Name'
      DesiredValues:
        - running

  # now that the Server is running, wait X number of minutes for the Server to finish starting its apps
  - name: WaitForApps
    action: 'aws:sleep'
    inputs:
      Duration: '{{SleepDuration}}'
  DOC
}
