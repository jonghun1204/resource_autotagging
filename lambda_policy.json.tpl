{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "${sqs_queue_arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:ListGroupsForUser",
                "iam:ListUsers",
                "iam:TagRole",
                "iam:TagPolicy",
                "cloud9:TagResource",
                "ec2:CreateTags",
                "s3:PutBucketTagging",
                "dynamodb:TagResource",
                "lambda:TagResource",
                "rds:AddTagsToResource",
                "sqs:TagQueue",
                "sns:TagResource",
                "sqs:GetQueueUrl",
                "sagemaker:AddTags",
                "cloudfront:TagResource",
                "apigateway:PUT",
                "apigateway:PATCH",
                "apigateway:POST",
                "ecs:TagResource",
                "elasticloadbalancing:AddTags",
                "ecr:TagResource"
            ],
            "Resource": "*"
        }
    ]
}

