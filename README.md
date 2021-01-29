# lambda-http-native

## Usage


Example usage with dynamo db app. Policy for all tables and logs in Account.

```
resource "aws_iam_policy" "dynamodbPolicy" {
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem"

            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup"
            ],
            "Resource": "arn:aws:logs:eu-central-1:*:*"
        }
    ]
}
EOF
}



module "my-name" {
  source = "github.com/konradzawadka/lambda-http-native"
  name = "my-name"
  policy_arn = aws_iam_policy.dynamodbPolicy.arn
  env_variables = {
    DISABLE_SIGNAL_HANDLERS = "true"
    SOME_VAR = "test"
  }
}
```
