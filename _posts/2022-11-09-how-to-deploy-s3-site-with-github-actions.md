---
title: How To Deploy an S3 Site with Github Actions
date: 2022-11-08 00:00:00 +/-TTTT
categories: [HowTos, AWS]
tags: [terraform, github actions, github, ci/cd, pipelines]     # TAG names should always be lowercase
mermaid: true
toc: true
---

If you haven't read the [Landing Page Project Kickoff](/posts/project-kickoff-landing-page/) or the [How To Setup Route53 with Terraform](/posts/2022-11-08-how-to-setup-route53-with-terraform) post, this post builds upon both of those. At a minimum, this guide requires a public hosted zone created in Route53.

1. Setup the repo
2. Setup the infrastructure
3. Setup the pipeline

# Static Site
```terraform
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "terraform-aws-modules-example.com"

  force_destroy       = true

  acl = "private" # "acl" conflicts with "grant" and "owner"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  website = {

    index_document = "index.html"
    error_document = "error.html"
  }

  # Bucket policies
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.bucket_policy.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

}

data "aws_iam_policy_document" "bucket_policy" {
  statement {

    sid = "CloudfrontReadObject"

    principals {
      type        = "AWS"
      identifiers = module.cdn.cloudfront_origin_access_identity_iam_arns
    }

    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      module.s3_bucket.s3_bucket_arn,
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = ["www.terraform-aws-modules-example.com", "terraform-aws-modules-example.com"]

  comment             = "My awesome CloudFront"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false
  default_root_object = "index.html" # Super important - https://serverfault.com/questions/581268/amazon-cloudfront-with-s3-access-denied

  create_origin_access_identity = true
  origin_access_identities = {
    s3_bucket_one = "My awesome CloudFront can access"
  }

  origin = {
    s3_one = {
      domain_name = module.s3_bucket.s3_bucket_bucket_regional_domain_name
      s3_origin_config = {
        origin_access_identity = "s3_bucket_one" # key in `origin_access_identities`
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = "s3_one"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  viewer_certificate = {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = "terraform-aws-modules-example.com"
  zone_id      = "Z123456789YV12345M1SQ"

  subject_alternative_names = [
    "*.terraform-aws-modules-example.com",
  ]

  wait_for_validation = true
  create_route53_records = true

  tags = {
    Name = "terraform-aws-modules-example.com"
  }
}

##########
# Route53
##########

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_id = "Z123456789YV12345M1SQ"

  records = [
    {
      name = ""
      type = "A"
      alias = {
        name    = module.cdn.cloudfront_distribution_domain_name
        zone_id = module.cdn.cloudfront_distribution_hosted_zone_id
      }
    },
    {
      name = "www"
      type = "A"
      alias = {
        name    = module.cdn.cloudfront_distribution_domain_name
        zone_id = module.cdn.cloudfront_distribution_hosted_zone_id
      }
    },
  ]
}

```

# Deployment Role
```terraform
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

module "github_actions_s3_deploy_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name = "github-actions-s3-deploy-role"

  provider_url = aws_iam_openid_connect_provider.github_actions.url

  role_policy_arns = [
    aws_iam_policy.github_actions_s3_deploy.arn
  ]

  number_of_role_policy_arns = 1
}


resource "aws_iam_policy" "github_actions_s3_deploy" {
  name = "github-actions-s3-deploy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowSync",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:Listbucket",
          "s3:PutObject"
        ],
        "Resource" : "*"
      }
    ]
  })
}
```

# Github Action
```yaml
{% raw %}
name: Upload Website

on:
 push:
   branches:
     - main
     - master

permissions:
  id-token: write
  contents: read

jobs:
 Deploy:
   runs-on: ubuntu-latest
   steps:
     - name: Checkout
       uses: actions/checkout@v2

     - name: Configure AWS credentials from Test account
       uses: aws-actions/configure-aws-credentials@v1
       with:
         role-to-assume: ${{ secrets.AWS_ROLE }}
         aws-region: ${{ secrets.AWS_REGION }}

     - name: Deploy static site to S3 bucket
       run: aws s3 sync ./src s3://${{ secrets.BUCKET_NAME }}
{% endraw %}
```