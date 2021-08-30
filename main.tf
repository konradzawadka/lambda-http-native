resource "aws_lambda_function" "lambda" {
  function_name = "${var.name}_fun"
  filename = var.package_filename
  source_code_hash = filebase64sha256(var.package_filename)
  
  handler = var.handler
  runtime = var.runtime
  role = aws_iam_role.lambda_exec.arn
  memory_size = var.ram
  timeout = "20"
  environment {
    variables = var.env_variables
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "lambda_exec" {
  name = "${var.name}_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole-attachment" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



resource "aws_iam_role_policy_attachment" "lambda_policy-attachment" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = var.policy_arn
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = var.name
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = var.cors_allow_headers
    allow_origins = var.cors_allow_origins
    allow_methods = var.cors_allow_methods
  }
}

resource "aws_apigatewayv2_route" "lambda" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}


# 
#     CERTIFICATE
# 
resource "aws_acm_certificate" "lambda_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "lambda_zone" {
  name         = var.zone
  private_zone = false
}

resource "aws_route53_record" "lambda_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.lambda_cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.lambda_zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "lambda_cert_validation" {
  certificate_arn         = aws_acm_certificate.lambda_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.lambda_validation_record : record.fqdn]
}


# 
#   DOMAIN CREATION
# 

resource "aws_apigatewayv2_domain_name" "lambda_domain" {
  domain_name = var.domain_name
  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.lambda_cert_validation.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "app_cname_record" {
  name    = aws_apigatewayv2_domain_name.lambda_domain.domain_name
  type    = "A"
  zone_id = aws_route53_zone.lambda_zone.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.lambda_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.lambda_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
  
  
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id
  name   = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id    = aws_apigatewayv2_api.lambda.id
  integration_type = "AWS_PROXY"
  payload_format_version  = "2.0"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.lambda.invoke_arn
}
  
resource "aws_apigatewayv2_api_mapping" "lambda_mapping" {
  api_id      = aws_apigatewayv2_api.lambda.id
  domain_name = aws_apigatewayv2_domain_name.lambda_domain.id
  stage       = aws_apigatewayv2_stage.lambda.id
}

resource "aws_lambda_permission" "apigw" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
