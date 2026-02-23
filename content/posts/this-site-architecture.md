---
title: This Site Architecture
date: 2026-02-14T19:21:14+02:00
draft: false
author:
  name: Omer Benisty
description:
tags:
  - Linux
  - Github Actions
  - CI/CD
  - AWS
categories:
  - Architecture
featuredImage:
featuredImagePreview:
---

It seems like every tech person have a website nowadays so on a random weekend I've stayed at my parents I decided it is time to make a corner at the
internet about myself.

## Introduction

Few keypoints this site had to fulfill
- Using platforms/tools I'm using in my line of work
- Cost efficient and cheap to maintain
- Simple deploy and content management
- A complete framework for the Front-End
- Serverless

<!--more-->

**Diagram**
> Monitoring will be added in the future

<img src="/images/benisty.sh-diagram.svg" alt="Architecture Diagram" style="width: 65%; border: 1px solid #333; border-radius: 4px; padding: 8px;">

Let's dive in a little bit more.

## Application & Hosting

As you saw in the diagram I decided to go with [hugo](https://gohugo.io/) as my main framework, it does all the heavy lifting regarding front-end using premade themes and generate an organised folder containing all static files ready for production.

### Setting up Hugo

Setting it up is super easy, the only requirement for hugo is git (except some very niche use cases) and right after you can usually install it from you favorite package manager.

```bash
# Fedora
sudo dnf install hugo -y

# Ubuntu
sudo apt install hugo -y

# Arch
sudo pacman -S hugo
```
After we have hugo installed we can create our project and add a theme of our choice, downloading themes is done by using git submodules and specifying the theme in hugo's configuration file `hugo.toml`.

```bash
hugo new project quickstart
cd quickstart
git init
git submodule add https://github.com/hugo-fixit/FixIt.git themes/FixIt
echo "theme = 'FixIt'" >> hugo.toml
```
After that we can run hugo to build and serve our site locally so we can start developing it.
```bash
hugo server -D
```
{{< admonition >}}
With hugo running we can go to `http://localhost:1313` and view our site, hugo creates a live preview meaning you can view your changes in real time without restarting hugo.
{{< /admonition >}}

### Creating our S3
Let's create a home place for our hugo site, I work regularly with AWS so I decided to remain in my comfort zone in that regard, the main difficulty was choosing between [AWS Amplify](https://aws.amazon.com/amplify/) or [S3](https://aws.amazon.com/s3/).
Amplify has basically everything you'll even want for deploying web frameworks, it has support for any server side framework, provides global avaliability and low latency using CloudFront and is super easy to deploy to using a Git-based workflow but two main thing made me turn to S3.

**Cost** and **complexity**, keeping things simple and cost efficient is one of the most important caviats you have to deal with when creating an architecture and this one is no different, S3 is much cheaper and simpler making it our best candidate.

So I created our S3 bucket using Terraform, a simple bucket that serves static files with a policy designed for CloudFront
```hcl
resource "aws_s3_bucket" "website" {
  bucket = "My-S3-Name"
}
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          ArnLike = {
            "AWS:SourceArn" = "arn:aws:cloudfront::705778161892:distribution/REDACTED_DISTRIBUTION_ID"
          }
        }
      },
      {
        Sid       = "DenyInsecurePolicy"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```