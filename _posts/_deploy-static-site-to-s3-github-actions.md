---
title: Deploy a Static Site to S3 with Github Actions
date: 2022-11-20 00:00:00 +/-TTTT
categories: [Tutorials, AWS]
tags: [terraform, github actions, github, ci/cd, pipelines]     # TAG names should always be lowercase
mermaid: true
---

If you haven't read the [Landing Page Project Kickoff](/posts/project-kickoff-landing-page/), this post builds upon the design proposed during the hypothetical planning.

1. Setup the repo
2. Setup the infrastructure
3. Setup the pipeline

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
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowPushPull",
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "s3:DeregisterTaskDefinition",
          "s3:DescribeServices",
          "s3:DescribeTaskDefinition",
          "s3:DescribeTasks",
          "s3:ListTasks",
          "s3:ListTaskDefinitions",
          "s3:RegisterTaskDefinition",
          "s3:StartTask",
          "s3:StopTask",
          "s3:UpdateService",
          "iam:PassRole"
        ],
        "Resource": "*"
      }
    ]
  })
}
```