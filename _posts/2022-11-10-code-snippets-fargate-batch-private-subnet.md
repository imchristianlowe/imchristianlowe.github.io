---
title: Fargate Batch Private Subnet
date: 2022-11-10 00:00:00 +/-TTTT
categories: [Code Snippets, Terraform]
tags: [terraform, batch, fargate, vpc endpoint]     # TAG names should always be lowercase
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

  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = false

  public_route_table_tags  = { Name = "${local.name}-public" }
  public_subnet_tags       = { Name = "${local.name}-public" }
  private_route_table_tags = { Name = "${local.name}-private" }
  private_subnet_tags      = { Name = "${local.name}-private" }

  enable_dhcp_options  = true
  enable_dns_hostnames = true
#   dhcp_options_domain_name = data.aws_region.current.name == "us-east-1" ? "ec2.internal" : "${data.aws_region.current.name}.compute.internal"

  vpc_tags = {
    Name = "vpc-name"
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoint_security_group.security_group_id]

  endpoints = {
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
  }

  tags = local.tags
}
```

# Batch Module
```terraform
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
  source = "terraform-aws-modules/batch/aws"
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

        security_group_ids = [module.vpc_endpoint_security_group.security_group_id]
        subnets            = module.vpc.private_subnets

        # `tags = {}` here is not applicable for spot
      }
    }

    b_fargate_spot = {
      name_prefix = "fargate_spot"

      compute_resources = {
        type      = "FARGATE_SPOT"
        max_vcpus = 4

        security_group_ids = [module.vpc_endpoint_security_group.security_group_id]
        subnets            = module.vpc.private_subnets

        # `tags = {}` here is not applicable for spot
      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name     = "LowPriorityFargate"
      state    = "ENABLED"
      priority = 1

      tags = {
        JobQueue = "Low priority job queue"
      }
    }

    high_priority = {
      name     = "HighPriorityFargate"
      state    = "ENABLED"
      priority = 99

      fair_share_policy = {
        compute_reservation = 1
        share_decay_seconds = 3600

        share_distribution = [{
          share_identifier = "A1*"
          weight_factor    = 0.1
          }, {
          share_identifier = "A2"
          weight_factor    = 0.2
        }]
      }

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
      })

      attempt_duration_seconds = 60
      retry_strategy = {
        attempts = 3
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

################################################################################
# Supporting Resources
################################################################################

module "vpc_endpoint_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-vpc-endpoint"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_with_self = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Container to VPC endpoint service"
      self        = true
    },
  ]

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
```