module "provisoner_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 5.0"

  function_name = var.lambda_name
  handler       = "index.lambda_handler"
  runtime       = "python3.9"

  source_path = "${path.module}/lambda"
  #local_existing_package = data.archive_file.lambda.output_path

  create_current_version_allowed_triggers = false

  vpc_subnet_ids         = var.vpc_config.subnet_ids
  vpc_security_group_ids = var.vpc_config.security_group_ids
  #   compact(concat(var.vpc_config.security_group_ids, [join("", aws_security_group.default.*.id)]))

  role_name = "${var.lambda_name}-role"

  attach_policy_statements = true
  policy_statements = {
    # Allow Lambda to access VPC resource
    vpc_access = {
      effect = "Allow"
      actions = [
        "ec2:DescribeInstances",
        "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ]
      resources = [var.rds_arn]
    }
  }

  attach_policies    = true
  number_of_policies = 4

  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  ]

  environment_variables = {
    RDS_HOST                      = var.rds_endpoint
    RDS_PORT                      = var.rds_port
    DB_USER_SECRET_MANAGER_NAME   = var.rds_user_secret_name
    DB_MASTER_SECRET_MANAGER_NAME = var.rds_master_user_secret_name
  }

  layers = [
    data.aws_lambda_layer_version.psycopg2_lambda_layer.arn
  ]
}

data "aws_lambda_layer_version" "psycopg2_lambda_layer" {
  layer_name = "psycopg2"

  depends_on = [aws_lambda_layer_version.psycopg2_lambda_layer]
}

data "aws_lambda_invocation" "default" {
  count = var.enabled && var.invoke ? 1 : 0

  depends_on = [
    module.provisoner_lambda
  ]

  function_name = module.provisoner_lambda.lambda_function_name
  input         = ""
}

resource "aws_lambda_layer_version" "psycopg2_lambda_layer" {
  layer_name  = "psycopg2"
  description = "A layer to enable psycopg2 for python3.9"

  filename                 = "${path.module}/lambda_layers/psycopg2_layer.zip"
  compatible_runtimes      = ["python3.9"]
  compatible_architectures = ["x86_64"]
}
