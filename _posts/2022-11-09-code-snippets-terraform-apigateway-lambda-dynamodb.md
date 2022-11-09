---
title: API Gateway -> Lambda -> Dynamodb
date: 2022-11-09 00:00:00 +/-TTTT
categories: [Code Snippets, Terraform]
tags: [terraform, dynamodb, apigateway, lambda]     # TAG names should always be lowercase
mermaid: true
toc: true
---

```terraform
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "domain" = {
      domain_name = local.domain
      comment = "${local.domain} (production)"
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

  domain_name  = module.zones.route53_zone_name["domain"]
  zone_id      = module.zones.route53_zone_zone_id["domain"]

  subject_alternative_names = [
    "*.${module.zones.route53_zone_name["domain"]}",
  ]

  wait_for_validation = true
  create_route53_records = true

}

##########
# Route53
##########

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_name = module.zones.route53_zone_name["domain"]

  records = [
    {
      name = "api"
      type = "A"
      alias = {
        name    = module.api_gateway.apigatewayv2_domain_name_configuration[0].target_domain_name
        zone_id = module.api_gateway.apigatewayv2_domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = false
      }
    },
  ]

  depends_on = [
    module.zones
  ]
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 2.0"

  name          = "dev-http"
  description   = "My awesome HTTP API Gateway"
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  # Custom domain
  domain_name                 = "api.${module.zones.route53_zone_name["domain"]}"
  domain_name_certificate_arn = module.acm.acm_certificate_arn

  # Routes and integrations
  integrations = {
    
    "GET /some-route-with-authorizer" = {
      integration_type = "HTTP_PROXY"
      integration_uri  = "http://ip.jsontest.com/"
    }

    "$default" = {
      integration_type = "HTTP_PROXY"
      integration_uri  = "http://ip.jsontest.com/"
    }

    "ANY /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
    }
  }

  tags = {
    Name = "http-apigateway"
  }
}


module "dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 3.0"

  name     = "my-table"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "N"
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "staging"
  }
}

#############################################
# Using packaged function from Lambda module
#############################################

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "api-lambda"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  publish = true

  create_package         = false
  local_existing_package = data.archive_file.lambda_zip_inline.output_path

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow",
      actions   = ["dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      resources = [module.dynamodb_table.dynamodb_table_arn]
    }
  }

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }
}

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
  source {
    content  = <<EOF

import boto3
client = boto3.client(
  'dynamodb',
  region_name='us-east-1',
)

def lambda_handler(event, context):
    item = client.put_item(
        TableName='my-table',
        Item={
            "id": { "N": "1" }
        } 
    )
    return "hello world"

EOF
    filename = "index.py"
  }
}
```