/*
    ChatGPTのbotをデプロイする
    参考　https://dev.classmethod.jp/articles/slack-chat-gpt-bot/
*/

/*
    変数の設定
*/
# .envrcから取得する 
variable "slackChatGptBotNode_slackSigningSecret" {
  type = string
}
variable "slackChatGptBotNode_slackBotToken" {
  type = string
}
variable "slackChatGptBotNode_openAiApiKey" {
  type = string
}

resource "aws_ssm_parameter" "slackChatGptBotNode_slackSigningSecret" {
  name  = "slackChatGptBotNode_slackSigningSecret"
  type  = "String"
  value = var.slackChatGptBotNode_slackSigningSecret
}

resource "aws_ssm_parameter" "slackChatGptBotNode_slackBotToken" {
  name  = "slackChatGptBotNode_slackBotToken"
  type  = "String"
  value = var.slackChatGptBotNode_slackBotToken
}

resource "aws_ssm_parameter" "slackChatGptBotNode_openAiApiKey" {
  name  = "slackChatGptBotNode_openAiApiKey"
  type  = "String"
  value = var.slackChatGptBotNode_openAiApiKey
}


# /*
#     DynamoDB
# */
# resource "aws_dynamodb_table" "slackChatGptBotNode_messages_table" {
#   name           = "slackChatGptBotNode_messages"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "id"
#   # PAY_PER_REQUESTのときは read/write_capacityを選択できない
#   # read_capacity  = 1
#   # write_capacity = 1

#   attribute {
#     name = "id"
#     type = "S"
#   }

#   attribute {
#     name = "threadTs"
#     type = "S"
#   }

#   global_secondary_index {
#     name            = "threadTsIndex"
#     hash_key        = "threadTs"
#     projection_type = "ALL"
#   }

#   lifecycle {
#     prevent_destroy = false
#   }
# }

# /*
#     Lambda
# */
# resource "aws_iam_role" "lambda_execution_role" {
#   name = "lambda_execution_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "basic_execution" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
#   role       = aws_iam_role.lambda_execution_role.name
# }

# resource "aws_iam_role_policy" "dynamodb_access" {
#   name = "dynamodb_access"
#   role = aws_iam_role.lambda_execution_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:UpdateItem",
#           "dynamodb:DeleteItem",
#           "dynamodb:Query",
#           "dynamodb:Scan"
#         ]
#         Effect   = "Allow"
#         Resource = aws_dynamodb_table.slackChatGptBotNode_messages_table.arn
#       }
#     ]
#   })
# }


# resource "aws_lambda_function" "slackChatGptBotNode_api_fn" {
#   function_name = "slackChatGptBotNode_apiFn"
#   runtime       = "nodejs18.x"
#   handler       = "handler.handler"
#   role          = aws_iam_role.lambda_execution_role.arn
#   filename      = "./chatgptslackbot/src/compiled_lambda_code.zip"

#   environment {
#     variables = {
#       SLACK_SIGNING_SECRET = aws_ssm_parameter.slackChatGptBotNode_slackSigningSecret.value
#       SLACK_BOT_TOKEN      = aws_ssm_parameter.slackChatGptBotNode_slackBotToken.value
#       OPEN_AI_API_KEY      = aws_ssm_parameter.slackChatGptBotNode_openAiApiKey.value
#       MESSAGES_TABLE_NAME  = aws_dynamodb_table.slackChatGptBotNode_messages_table.name
#     }
#   }

#   timeouts {
#     create = "1m"
#   }
# }

# resource "aws_lambda_permission" "allow_apigw" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.slackChatGptBotNode_api_fn.function_name
#   principal     = "apigateway.amazonaws.com"
# }

# /*
#     API GW
# */
# resource "aws_api_gateway_rest_api" "api" {
#   name = "api"
# }

# resource "aws_api_gateway_deployment" "deployment" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   stage_name  = "api"
#   depends_on  = [aws_api_gateway_integration.integration]
# }

# resource "aws_api_gateway_resource" "resource" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   parent_id   = aws_api_gateway_rest_api.api.root_resource_id
#   path_part   = "{proxy+}"
# }

# resource "aws_api_gateway_method" "method" {
#   rest_api_id   = aws_api_gateway_rest_api.api.id
#   resource_id   = aws_api_gateway_resource.resource.id
#   http_method   = "ANY"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "integration" {
#   rest_api_id             = aws_api_gateway_rest_api.api.id
#   resource_id             = aws_api_gateway_resource.resource.id
#   http_method             = aws_api_gateway_method.method.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.slackChatGptBotNode_api_fn.invoke_arn
# }

# output "api_gateway_endpoint" {
#   description = "The API Gateway endpoint URL"
#   value       = aws_api_gateway_deployment.deployment.invoke_url
# }
