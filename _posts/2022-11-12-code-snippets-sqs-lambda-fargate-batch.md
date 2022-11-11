---
title: SQS -> Lambda -> Fargate Batch (w/ DLQ)
date: 2022-11-11 00:00:00 +/-TTTT
categories: [Code Snippets, Terraform]
tags: [terraform, batch, fargate, sqs, lambda]     # TAG names should always be lowercase
mermaid: true
toc: true
---

# Prerequisite Infra
```terraform
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "domain" = {
      domain_name = local.domain
      comment     = "${local.domain} (production)"
      tags = {
        env = "production"
      }
    }

  }

  tags = {
    ManagedBy = "Terraform"
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = module.zones.route53_zone_name["domain"]
  zone_id     = module.zones.route53_zone_zone_id["domain"]

  subject_alternative_names = [
    "*.${module.zones.route53_zone_name["domain"]}",
  ]

  wait_for_validation    = true
  create_route53_records = true

}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18.1"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_ipv6 = true

  enable_nat_gateway      = false
  single_nat_gateway      = false
  map_public_ip_on_launch = false

  public_route_table_tags  = { Name = "${local.name}-public" }
  public_subnet_tags       = { Name = "${local.name}-public" }
  private_route_table_tags = { Name = "${local.name}-private" }
  private_subnet_tags      = { Name = "${local.name}-private" }

  enable_dhcp_options  = true
  enable_dns_hostnames = true

  vpc_tags = {
    Name = "vpc-name"
  }
}
```

# Batch Module
```terraform

################################################################################
# Batch Module
################################################################################
locals {
  region = "us-east-1"
  name   = "batch-ex-fargate"

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-batch"
  }
}

module "batch" {
  source  = "terraform-aws-modules/batch/aws"
  version = "~> 1.2"

  instance_iam_role_name        = "${local.name}-ecs-instance"
  instance_iam_role_path        = "/batch/"
  instance_iam_role_description = "IAM instance role/profile for AWS Batch ECS instance(s)"
  instance_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  service_iam_role_name        = "${local.name}-batch"
  service_iam_role_path        = "/batch/"
  service_iam_role_description = "IAM service role for AWS Batch"
  service_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  create_spot_fleet_iam_role      = true
  spot_fleet_iam_role_name        = "${local.name}-spot"
  spot_fleet_iam_role_path        = "/batch/"
  spot_fleet_iam_role_description = "IAM spot fleet role for AWS Batch"
  spot_fleet_iam_role_tags = {
    ModuleCreatedRole = "Yes"
  }

  compute_environments = {
    a_fargate = {
      name_prefix = "fargate"

      compute_resources = {
        type      = "FARGATE"
        max_vcpus = 4

        security_group_ids = [module.batch_instance_security_group.security_group_id]
        subnets            = module.vpc.public_subnets

        # `tags = {}` here is not applicable for spot
      }
    }

    b_fargate_spot = {
      name_prefix = "fargate_spot"

      compute_resources = {
        type      = "FARGATE_SPOT"
        max_vcpus = 4

        security_group_ids = [module.batch_instance_security_group.security_group_id]
        subnets            = module.vpc.public_subnets

        # `tags = {}` here is not applicable for spot
      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name                     = "LowPriorityFargate"
      state                    = "ENABLED"
      priority                 = 1
      create_scheduling_policy = false
      tags = {
        JobQueue = "Low priority job queue"
      }
    }

    high_priority = {
      name                     = "HighPriorityFargate"
      state                    = "ENABLED"
      priority                 = 99
      create_scheduling_policy = false
      tags = {
        JobQueue = "High priority job queue"
      }
    }
  }

  job_definitions = {
    example = {
      name                  = local.name
      propagate_tags        = true
      platform_capabilities = ["FARGATE"]

      container_properties = jsonencode({
        command = ["ls", "-la"]
        image   = "public.ecr.aws/runecast/busybox:1.33.1"
        fargatePlatformConfiguration = {
          platformVersion = "LATEST"
        },
        resourceRequirements = [
          { type = "VCPU", value = "1" },
          { type = "MEMORY", value = "2048" }
        ],
        executionRoleArn = aws_iam_role.ecs_task_execution_role.arn
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = local.region
            awslogs-stream-prefix = local.name
          }
        }

        networkConfiguration = {
          assignPublicIp = "ENABLED"
        }
      })


      attempt_duration_seconds = 60
      retry_strategy = {
        attempts = 1
        evaluate_on_exit = {
          retry_error = {
            action       = "RETRY"
            on_exit_code = 1
          }
          exit_success = {
            action       = "EXIT"
            on_exit_code = 0
          }
        }
      }

      tags = {
        JobDefinition = "Example"
      }
    }
  }

  tags = local.tags
}

module "batch_instance_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-vpc-endpoint"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["https-443-tcp"]

  tags = local.tags
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.name}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/batch/${local.name}"
  retention_in_days = 1

  tags = local.tags
}

################################################################################
# SQS Batch Intake -> Batch Launcher Lambda (Includes DLQ)  
################################################################################
resource "aws_sqs_queue" "batch_intake_queue" {
  name = "batch-intake-queue"
}

resource "aws_sqs_queue" "batch_intake_dlq" {
  name = "batch-intake-dlq"
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.batch_intake_queue.arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "batch_intake_queue" {
  queue_url = aws_sqs_queue.batch_intake_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.batch_intake_dlq.arn
    maxReceiveCount     = 2
  })
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "batch_intake_queue_policy" {
  statement {
    effect = "Allow"

    actions = [
      "SQS:SendMessage"
    ]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.id]
    }

    resources = [
      aws_sqs_queue.batch_intake_queue.arn
    ]
  }

}

resource "aws_sqs_queue_policy" "batch_intake_queue" {
  queue_url = aws_sqs_queue.batch_intake_queue.id

  policy = data.aws_iam_policy_document.batch_intake_queue_policy.json
}


module "batch_launcher_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "batch-launcher"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  environment_variables = {
    BATCH_JOB   = module.batch.job_definitions["example"]["arn"]
    BATCH_QUEUE = module.batch.job_queues["low_priority"]["arn"]
  }

  publish = true

  create_package         = false
  local_existing_package = data.archive_file.lambda_zip_inline.output_path

  attach_policy_statements = true
  policy_statements = {
    batch = {
      effect    = "Allow",
      actions   = ["batch:SubmitJob"],
      resources = concat(
        [for k, v in module.batch.job_queues : v["arn"]], 
        [for k, v in module.batch.job_definitions : v["arn"]]
      )
    }
  }
  attach_policies    = true
  number_of_policies = 1

  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole",
  ]

  event_source_mapping = {
    sqs = {
      event_source_arn        = aws_sqs_queue.batch_intake_queue.arn
      function_response_types = ["ReportBatchItemFailures"]
    }
  }

  allowed_triggers = {
    sqs = {
      service    = "sqs"
      source_arn = aws_sqs_queue.batch_intake_queue.arn
    }
  }

}

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
  source {
    content  = <<EOF

import boto3
import os
import uuid

client = boto3.client(
  'batch',
  region_name='us-east-1',
)

def lambda_handler(event, context):
  response = client.submit_job(
    jobName=str(uuid.uuid4()),
    jobQueue=os.environ.get("BATCH_QUEUE"),
    jobDefinition=os.environ.get("BATCH_JOB")
  )
  return response

EOF
    filename = "index.py"
  }
}
```