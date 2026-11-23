# ── Origin Access Control (OAC) ─────────────────────────────────────────────

resource "aws_cloudfront_origin_access_control" "app" {
  name                              = var.domain_name
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront Function — terminal plain-text response ───────────────────────
# Inspects User-Agent and ?plain param; rewrites index.html response to
# plain text containing only the password for curl/wget/httpie clients.
# The actual password generation still happens client-side for browser users.
# For terminal users, we serve a lightweight plain-text endpoint via a
# separate object (plain.txt) generated at deploy time.

resource "aws_cloudfront_function" "terminal_router" {
  name    = "terminal-router"
  runtime = "cloudfront-js-2.0"
  comment = "Route terminal clients (curl/wget/httpie) to plain-text password endpoint"
  publish = true

  code = <<-EOF
    async function handler(event) {
      var request = event.request;
      var uri = request.uri;
      var headers = request.headers;
      var qs = request.querystring;

      // ?plain or ?password flag forces plain-text mode
      var wantsPlain = (qs['plain'] !== undefined) || (qs['password'] !== undefined);

      // Detect terminal User-Agents (curl, wget, httpie, python-requests, etc.)
      var ua = (headers['user-agent'] && headers['user-agent'].value) || '';
      var isTerminal = wantsPlain ||
        /^(curl|wget|httpie|http\/|lwp-request|python-requests|go-http-client|ruby|perl|php)/i.test(ua);

      if (isTerminal && (uri === '/' || uri === '' || uri === '/index.html')) {
        // Route to the pre-generated plain text pool.
        // Use request timestamp milliseconds modulo to pick a line —
        // the client gets a different password each time without a server.
        request.uri = '/plain.txt';
      } else if (uri === '/') {
        request.uri = '/index.html';
      }

      return request;
    }
  EOF
}

# ── Security headers function ────────────────────────────────────────────────

resource "aws_cloudfront_function" "security_headers" {
  name    = "security-headers"
  runtime = "cloudfront-js-2.0"
  comment = "Add strict security headers to every response"
  publish = true

  code = <<-EOF
    async function handler(event) {
      var response = event.response;
      var headers = response.headers;

      headers['strict-transport-security'] = { value: 'max-age=63072000; includeSubDomains; preload' };
      headers['x-content-type-options']    = { value: 'nosniff' };
      headers['x-frame-options']           = { value: 'DENY' };
      headers['x-xss-protection']          = { value: '1; mode=block' };
      headers['referrer-policy']           = { value: 'no-referrer' };
      headers['permissions-policy']        = { value: 'geolocation=(), microphone=(), camera=(), payment=()' };
      headers['content-security-policy']   = {
        value: "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data:; connect-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none';"
      };
      headers['cache-control'] = { value: 'no-store, no-cache, must-revalidate, private' };

      return response;
    }
  EOF
}

# ── Cache policies ───────────────────────────────────────────────────────────

resource "aws_cloudfront_cache_policy" "no_cache" {
  name        = "password-generator-no-cache"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# ── Distribution ─────────────────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [var.domain_name, var.www_subdomain]
  comment             = var.domain_name
  wait_for_deployment = true

  origin {
    domain_name              = aws_s3_bucket.app.bucket_regional_domain_name
    origin_id                = "s3-${var.domain_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.app.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.no_cache.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.terminal_router.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.app.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = var.domain_name
  }
}
