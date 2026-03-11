resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "s3-website"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cloudfront.identity
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for benisty.sh"
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-website"
    
    forwarded_values {
      query_string = false
      headers      = []
      
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    
    function_association {
      function_arn = aws_cloudfront_function.cache_key_function.arn
      event_type   = "viewer-request"
    }
  }
  
  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-website"
    
    forwarded_values {
      query_string = false
      headers      = []
      
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }
  
  price_class = "PriceClass_100"
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name        = "benisty.sh-cloudfront"
    Environment = "production"
  }
}

resource "aws_cloudfront_origin_access_identity" "cloudfront" {
  comment = "Origin access identity for benisty.sh CloudFront distribution"
}

resource "aws_cloudfront_function" "cache_key_function" {
  name    = "benisty.sh-cache-key"
  runtime = "cloudfront-js-1.0"
  type    = "VIEWER_REQUEST"
  
  code = <<EOF
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else if (!uri.includes('.')) {
    request.uri = uri + '/index.html';
  }
  
  return request;
}
EOF
}
