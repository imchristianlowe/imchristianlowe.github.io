---
title: How To Deploy an S3 Site with Github Actions
date: 2022-11-09 00:00:00 +/-TTTT
categories: [HowTos, AWS]
tags: [terraform, github actions, github, ci/cd, pipelines]     # TAG names should always be lowercase
mermaid: true
toc: true
---

```terraform
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "replace-me.com" = {
      comment = "replace-me.com (production)"
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

  domain_name  = "replace-me.com"
  zone_id      = "Z020998632YV431S6M1SQ"

  subject_alternative_names = [
    "*.replace-me.com",
  ]

  wait_for_validation = true
  create_route53_records = true

  tags = {
    Name = "replace-me.com"
  }
}

##########
# Route53
##########

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_id = "Z020998632YV431S6M1SQ"

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
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = "dev-http"
  description   = "My awesome HTTP API Gateway"
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  # Custom domain
  domain_name                 = "api.replace-me.com"
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
  }

  tags = {
    Name = "http-apigateway"
  }
}



```