resource "aws_lambda_function" "example" {
  function_name = "${var.name}_fun"
  filename = var.package_filename

  handler = "native.handler"
  runtime = "provided"
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

resource "aws_api_gateway_rest_api" "quarkus_gateway" {
  name = var.name
  description = var.name
}

resource "aws_api_gateway_resource" "quarkus_proxy" {
  rest_api_id = aws_api_gateway_rest_api.quarkus_gateway.id
  parent_id = aws_api_gateway_rest_api.quarkus_gateway.root_resource_id
  path_part = "{proxy+}"
}


resource "aws_api_gateway_method" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.quarkus_gateway.id
  resource_id = aws_api_gateway_resource.quarkus_proxy.id
  http_method = "ANY"
  authorization = "NONE"
}


resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.quarkus_gateway.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.example.invoke_arn
}


resource "aws_api_gateway_deployment" "quarkus_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda,
  ]

  rest_api_id = aws_api_gateway_rest_api.quarkus_gateway.id
  stage_name = "prod"
  variables = {
    deployed_at = filesha256(var.package_filename)
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.quarkus_gateway.execution_arn}/*/*"
}