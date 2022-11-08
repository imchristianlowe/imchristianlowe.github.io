---
title: AWS Route53 Setup with Terraform
date: 2022-11-25 00:00:00 +/-TTTT
categories: [HowTos, Aws]
tags: [terraform, aws, route53, cloud]     # TAG names should always be lowercase
---

When a user registers for an AWS account, a default VPC is generated to place resources in as the user creates them in the account, but no hosted zone is created. While it's possible to host applications on AWS with a custom domain name that is not registered with AWS and/or the DNS provider is not AWS, there are some nice integration features we can use with various AWS services if we use AWS Rotue53 as our DNS provider.

There are many other tutorials on how to register a domain with AWS, so that won't be covered here. If you're lost, the [AWS guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure) on how to register a domain with Route53 is a great place to start.

Once a domain is registered with Aws, we can use Terraform to manage Route53 resources. If you are unfamiliar with Terraform, it is an Infrastructure as Code (IaC) tool which allows a user to generate 

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

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_name = keys(module.zones.route53_zone_zone_id)[0]

  records = [
    {
      name    = "apigateway1"
      type    = "A"
      alias   = {
        name    = "d-10qxlbvagl.execute-api.eu-west-1.amazonaws.com"
        zone_id = "ZLY8HYME6SFAD"
      }
    },
    {
      name    = ""
      type    = "A"
      ttl     = 3600
      records = [
        "10.10.10.10",
      ]
    },
  ]

  depends_on = [module.zones]
}
```

From this example, there are two types of resources to create. A `zone` and a `record`.

From the [AWS Docs](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html) a hosted zone is

> A hosted zone is a container for records, and records contain information about how you want to route traffic for a specific domain, such as example.com, and its subdomains (acme.example.com, zenith.example.com). A hosted zone and the corresponding domain have the same name. There are two types of hosted zones:
- Public hosted zones contain records that specify how you want to route traffic on the internet. For more information, see Working with public hosted zones.
- Private hosted zones contain records that specify how you want to route traffic in an Amazon VPC. For more information, see Working with private hosted zones.

Choose the type of zone that is appropriate for you.

From the [AWS Docs](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/rrsets-working-with.html) a record is

>After you create a hosted zone for your domain, such as example.com, you create records to tell the Domain Name System (DNS) how you want traffic to be routed for that domain.
For example, you might create records that cause DNS to do the following:
- Route internet traffic for example.com to the IP address of a host in your data center.
- Route email for that domain (ichiro@example.com) to a mail server (mail.example.com).
- Route traffic for a subdomain called operations.tokyo.example.com to the IP address of a different host.
Each record includes the name of a domain or a subdomain, a record type (for example, a record with a type of MX routes email), and other information applicable to the record type (for MX records, the host name of one or more mail servers and a priority for each server). For information about the different record types, see Supported DNS record types.\
\
The name of each record in a hosted zone must end with the name of the hosted zone. For example, the example.com hosted zone can contain records for www.example.com and accounting.tokyo.example.com subdomains, but cannot contain records for a www.example.ca subdomain.