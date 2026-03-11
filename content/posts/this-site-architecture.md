---
title: This Site Architecture
date: 2026-02-14T19:21:14+02:00
draft: false
author:
  name: Omer Benisty
description: A walkthrough of how I built and deployed my personal site using Hugo, AWS S3, CloudFront, CloudFlare and GitHub Actions.
tags:
  - Linux
  - Github Actions
  - CI/CD
  - AWS
categories:
  - Architecture
featuredImage: /images/this-site-architecture/benisty.sh-diagram.svg
featuredImagePreview: /images/this-site-architecture/benisty.sh-diagram.svg
---

It seems like every tech person has a website nowadays so on a random weekend I stayed at my parents' I decided it was time to make a corner on the
internet about myself.

## Introduction

A few keypoints this site had to fulfill
- Using platforms/tools I'm using in my line of work
- Cost efficient and cheap to maintain
- Simple deploy and content management
- A complete framework for the Front-End
- Serverless

<!--more-->

**Diagram**
> Monitoring will be added in the future

<img src="/images/this-site-architecture/benisty.sh-diagram.svg" alt="Architecture Diagram" style="width: 65%; border: 1px solid #333; border-radius: 4px; padding: 8px;">

Let's dive in a little bit more.

## Application & Hosting

As you saw in the diagram I decided to go with [hugo](https://gohugo.io/) as my main framework, it does all the heavy lifting regarding front-end using premade themes and generates an organised folder containing all static files ready for production.

### Setting up Hugo

Setting it up is super easy, the only requirement for hugo is git (except some very niche use cases) and right after you can usually install it from your favorite package manager.

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
hugo new site quickstart
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

Let's create a home place for our hugo site, I work regularly with AWS so I decided to remain in my comfort zone in that regard, the main difficulty was choosing between [AWS Amplify](https://aws.amazon.com/amplify/) or [S3](https://aws.amazon.com/s3/), but since this project is relatively small and doesn't require any advanced features, I decided to go with S3.

An S3 bucket is a place to store your static files and it's a great place to host a static website as well with the [Website Hosting feature](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html).

I created an S3 with the Website Hosting feature turned on and also made sure the block public access toggle is on. Currently nothing really can access our bucket, let's change that.

### Our CDN CloudFront

Next up is our CDN, while we have a place to store our content we need to deliver it to people around the world, and that's where [CloudFront](https://aws.amazon.com/cloudfront/) comes in.

CloudFront is AWS's solution for content delivery, their large group of servers spread across the globe together with caching capability and generous free tier serve as a perfect candidate for our site. It's worth noting that while CloudFront does offer AWS WAF integration, it's a paid add-on so we won't be using it here — instead we'll handle that layer with CloudFlare later on.

I created the distribution and linked it to our S3 bucket. I also verified our domain through certificate manager as part of the process, we went with the default caching policy which is more than we need and pointed our root file to index.html.

As part of creating the distribution we also went back and edited our S3 bucket policy to allow CloudFront to access our files. The first statement grants the CloudFront service principal permission to read objects from our bucket, but only if the request originates from our specific distribution. The second statement denies any non-HTTPS traffic to the bucket:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::{Bucket Name}/*",
            "Condition": {
                "ArnLike": {
                    "AWS:SourceArn": "arn:aws:cloudfront::{Account ID}:distribution/{Distribution ID}"
                }
            }
        },
        {
            "Sid": "DenyInsecurePolicy",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::{Bucket Name}",
                "arn:aws:s3:::{Bucket Name}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
```

This way our bucket stays private — only our CloudFront distribution can read from it, and all traffic must be over HTTPS.

However we confronted a problem.

Hugo uses permalinks (custom URL patterns via permalinks in config or frontmatter) in order to serve our pages and CloudFront was not able to find our files, luckily a simple CloudFront Function solved the issue. 

```javascript
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Case 1: The URI ends with a trailing slash (e.g., /about/)
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    // Case 2: The URI has no file extension (e.g., /about)
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
```

This function checks if the URI ends with a trailing slash or has no file extension, and appends `index.html` to the URI if either condition is true. This ensures that CloudFront can correctly find the files and serve them.

### We love CloudFlare
We have our site and our CDN but no one on the internet knows where it is yet, so let's introduce CloudFlare.

You might be wondering why we need CloudFlare when we already have CloudFront as our CDN. The answer is simple: CloudFlare serves a different role here. CloudFront is our CDN — it caches and delivers our content from edge locations around the world. CloudFlare on the other hand is our DNS provider and WAF. CloudFlare's free tier includes DNS management and a solid WAF with DDoS protection out of the box, while CloudFront's WAF (AWS WAF) is a paid service. So the two complement each other nicely: CloudFront handles content delivery and caching, CloudFlare handles DNS resolution and security.

CloudFlare also makes DNS record updates almost instant since they manage both your DNS and WAF, which is great for trial and error.

After adding our domain to cloudflare by changing our nameservers let's create a DNS record pointing to our CloudFront distribution.


<img src="/images/this-site-architecture/cloudflare-screenshot-1.png" alt="Architecture Diagram" style="width: 100%; border: 1px solid #333; border-radius: 4px; padding: 8px;">

Perfect, now our domain is pointing to our CloudFront distribution together with CloudFlare's powerful WAF (the orange cloud icon), let's tweak our WAF a little bit.

I made sure TLS encryption mode was set to Full and redirected all traffic to HTTPS using a premade rule but we have another small problem to solve and that is caching.

Since CloudFlare is a full blown CDN they also have caching turned on by default, but if you paid attention we already have caching on CloudFront, double caching can cause several issues and also duplicate content and makes it difficult to manage so we turned it off with a simple rule.


<img src="/images/this-site-architecture/cloudflare-rule-3.png" alt="Architecture Diagram" style="width: 100%; border: 1px solid #333; border-radius: 4px; padding: 8px;">


We also blocked some countries that are known sources of high volumes of bot traffic and automated attacks while we were at it. Since this is a personal blog with no real audience in those regions, blocking them reduces noise in our logs and lowers the risk of malicious scanning or abuse hitting our infrastructure.


<img src="/images/this-site-architecture/cloudflare-rule-2.png" alt="Architecture Diagram" style="width: 100%; border: 1px solid #333; border-radius: 4px; padding: 8px;">


## Github Actions our CI/CD warrior

I basically fell in love with [Github Actions](https://github.com/features/actions) in the last few weeks so I had to use it in my project here.

As our development environment my own laptop felt sufficient, hugo is very easy to run and with the site being only static files we shouldn't encounter any compatibility issues so we really only need one pipeline and that is to go live to production.

```yaml
name: Deploy Hugo Site to S3

on:
  push:
    branches:
      - main 

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          submodules: true

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: 'latest'
          extended: true 

      - name: Build
        run: hugo --minify

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: (Our Region)

      - name: Deploy to S3
        run: aws s3 sync ./public s3://${{ secrets.S3_BUCKET_NAME }} --delete

      - name: Invalidate CloudFront Cache
        run: aws cloudfront create-invalidation --distribution-id ${{ secrets.AWS_CLOUDFRONT_DISTRIBUTION }} --paths "/*"

      - name: Purge Cloudflare Cache
        run: |
          curl -s -X POST "${{ secrets.CLOUDFLARE_CACHE_ENDPOINT }}" \
            -H "Authorization: Bearer ${{ secrets.CLOUDFLARE_API_TOKEN }}" \
            -H "Content-Type: application/json" \
            --data '{"purge_everything":true}'
```

Our pipeline is relatively simple:
- We setup hugo on an ubuntu machine using hugo's integrated tools
- Build our site
- Setup credentials for AWS
- Upload our static files to our S3
- Clears cache of CloudFront and Cloudflare

Even though we turned off CloudFlare's cache completely I preferred adding this into our pipeline in case we want to switch caching mechanisms in the future.

And now we can clone our repo, write some articles, push our changes and our site will be live in no time.