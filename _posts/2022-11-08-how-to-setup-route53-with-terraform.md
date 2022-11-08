---
title: How to Setup Route53 with Terraform
date: 2022-11-08 00:00:00 +/-TTTT
categories: [HowTos, AWS]
tags: [terraform, aws, route53, cloud]     # TAG names should always be lowercase
---

When a user registers for an AWS account, a default VPC is generated to place resources in as the user creates them in the account, but no hosted zone is created. While it's possible to host applications on AWS with a custom domain name that is not registered with AWS and/or the DNS provider is not AWS, there are some nice integration features we can use with various AWS services if we use AWS Rotue53 as our DNS provider.

There are many other tutorials on how to register a domain with AWS, so that won't be covered here. If you're lost, the [AWS guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure) on how to register a domain with Route53 is a great place to start.

Once a domain is registered with Aws, we can use Terraform to manage Route53 resources. If you are unfamiliar with Terraform, it is an Infrastructure as Code (IaC) tool which allows a user to generate infrastructure resources by running a few commands after writing a bit of code. From the [Terraform](https://terraform.io) site:

> Terraform codifies cloud APIs into declarative configuration files.

The benefits of using infrastructure as code won't be covered here but I encourage you to go out and read about it.

I'm a fan of [antonbabenko's](https://github.com/antonbabenko) Terraform modules. In my opinion, they are well documented and updated as Aws and Terraform add new features. For this guide [Route53](https://github.com/terraform-aws-modules/terraform-aws-route53) module to create resources for the domain registered above.

The README of the Route53 module provides an example we can get started with
```terraform
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "terraform-aws-modules-example.com" = {
      comment = "terraform-aws-modules-examples.com (production)"
      tags = {
        env = "production"
      }
    }

    "myapp.com" = {
      comment = "myapp.com"
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

```

From this example, there are two types of resources to create. A `zone` and a `record`.

From the [AWS Docs](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html) a hosted zone is

> A hosted zone is a container for records, and records contain information about how you want to route traffic for a specific domain, such as example.com, and its subdomains (acme.example.com, zenith.example.com). A hosted zone and the corresponding domain have the same name. There are two types of hosted zones:
- Public hosted zones contain records that specify how you want to route traffic on the internet. For more information, see Working with public hosted zones.
- Private hosted zones contain records that specify how you want to route traffic in an Amazon VPC. For more information, see Working with private hosted zones.

Choose the type of zone that is appropriate for your use case. The only difference when creating the zones is a VPC must be provided for a private zone so the resource block would look like the following:

```terraform
"private-vpc.terraform-aws-modules-example.com" = {
  # in case than private and public zones with the same domain name
  domain_name = "terraform-aws-modules-example.com"
  comment     = "private-vpc.terraform-aws-modules-example.com"
  vpc = [
    {
      vpc_id = module.vpc1.vpc_id
    },
    {
      vpc_id = module.vpc2.vpc_id
    },
  ]
  tags = {
    Name = "private-vpc.terraform-aws-modules-example.com"
  }
}
```

Output file should look like
```terraform
output "route53_zone_zone_id" {
  description = "Zone ID of Route53 zone"
  value       = module.zones.route53_zone_zone_id
}

output "route53_zone_zone_arn" {
  description = "Zone ARN of Route53 zone"
  value       = module.zones.route53_zone_zone_arn
}

output "route53_zone_name_servers" {
  description = "Name servers of Route53 zone"
  value       = module.zones.route53_zone_name_servers
}

output "route53_zone_name" {
  description = "Name of Route53 zone"
  value       = module.zones.route53_zone_name
}
```

Terraform refresh/output command produces
```bash
route53_zone_name = {
  "terraform-aws-modules-example.com" = "terraform-aws-modules-example.com"
}
route53_zone_name_servers = {
  "terraform-aws-modules-example.com" = tolist([
    "ns-1184.awsdns-20.org",
    "ns-1779.awsdns-30.co.uk",
    "ns-545.awsdns-04.net",
    "ns-97.awsdns-12.com",
  ])
}
route53_zone_zone_arn = {
  "terraform-aws-modules-example.com" = "arn:aws:route53:::hostedzone/Z123456789YV12345M1SQ"
}
route53_zone_zone_id = {
  "terraform-aws-modules-example.com" = "Z123456789YV12345M1SQ"
}
```