# AWS 리소스 자동 태깅 시스템

AWS에서 생성되는 리소스에 자동으로 그룹 및 사용자 태그를 추가하는 시스템입니다.

## 🏗️ 아키텍처

### 중앙 태깅 리전
- **EventBridge**: CloudTrail 이벤트를 감지
- **SQS**: 이벤트를 큐잉하여 Lambda로 전달
- **Lambda**: 실제 태깅 작업 수행

### 소스 리전 (태깅을 원하는 리전)
- **EventBridge**: CloudTrail 이벤트를 감지하여 중앙 리전으로 전달

## 📁 파일 구조

```
resource-autotagging/
├── lambda_function.py          # Lambda 함수 코드
├── event.json                  # EventBridge 이벤트 패턴 정의
├── lambda_policy.json.tpl      # Lambda IAM 정책 템플릿
└── terraform/
    ├── variables.tf            # 입력 변수 정의
    ├── outputs.tf              # 출력 값 정의
    ├── main.tf                 # 리소스 정의 (Provider, 데이터 소스, 리소스)
    └── terraform.tf            # Terraform 버전 및 Provider 설정
```

## 🚀 배포 방법

### 1. 사전 요구사항
- Terraform 설치
- AWS CLI 구성
- CloudTrail 활성화 필요

### 2. AWS 프로필과 태그 리전 설정

`terraform/variables.tf` 파일에서 default 값 수정:

```hcl
variable "aws_profile" {
  default = "myprofile"  # 사용할 프로필명으로 변경
}
```

```hcl
variable "central_tagging_region" {
  description = "중앙 태깅 리전"
  type        = string
  default     = "ap-northeast-2"  # 원하는 리전으로 변경
}
```

### 3. 소스 리전 비활성화

필요 없는 소스 리전은 빈 문자열로 설정

### 4. 실행

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

## 🔧 설정 파일 수정

### EventBridge 이벤트 패턴 수정 (`event.json`)

새로운 AWS 서비스나 이벤트를 추가하려면 `event.json` 파일을 수정:

```json
{
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": [
        "ec2.amazonaws.com",
        "s3.amazonaws.com",
        "새로운서비스.amazonaws.com"  // 추가
      ],
      "eventName": [
        "RunInstances",
        "CreateBucket",
        "새로운이벤트"  // 추가
      ],
      "userIdentity": {
        "type": ["IAMUser", "AssumedRole"]
      }
    }
}
```

파일 수정 후 `terraform apply`를 실행하면 자동 적용

### Lambda 정책 수정 (`lambda_policy.json.tpl`)

Lambda에 추가 권한이 필요한 경우 템플릿 파일을 수정:

```json
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
                "ec2:CreateTags",
                "새로운서비스:TagResource"  // 추가
            ],
            "Resource": "*"
        }
    ]
}
```

> **주의**: `${sqs_queue_arn}` 변수는 Terraform이 자동으로 치환하므로 수정 금지

## 📋 SQS 설정

현재 SQS 설정값:
- **Visibility Timeout**: 60초 (1분)
- **Delivery Delay**: 20초
- **Message Retention Period**: 600초 (10분)

이 값들은 `terraform/main.tf`의 SQS 리소스에서 수정 가능

## 🏷️ 태깅 규칙

Lambda 함수는 다음 태그를 자동으로 추가합니다:
- `group`: 사용자가 속한 IAM 그룹
- `username`: 리소스를 생성한 IAM 사용자 이름

## 🔍 지원 서비스

현재 지원되는 AWS 서비스:
- EC2 (인스턴스, 보안 그룹, EIP, 키페어 등)
- S3
- RDS
- Lambda
- DynamoDB
- SNS
- SQS
- IAM
- Cloud9
- ECS
- ECR
- API Gateway
- Elastic Load Balancing
- CloudFront
- SageMaker

## 📤 Outputs

배포 후 다음 정보를 출력합니다:

```bash
# 중앙 태깅 리전 정보
terraform output central_region                   # 중앙 리전
terraform output central_sqs_queue_url            # SQS Queue URL
terraform output central_lambda_function_name     # Lambda 함수 이름
terraform output central_eventbridge_rule_arn     # 중앙 EventBridge Rule ARN

# 소스 리전 정보
terraform output source_region_1                  # 소스 리전 
terraform output source_region_1_eventbridge_rule_arn  # 소스 리전 EventBridge Rule ARN

```

비활성화된 소스 리전은 "비활성화"로 표시됩니다.

## 🐛 트러블슈팅

### Lambda 실행 오류
CloudWatch Logs에서 Lambda 로그 확인

### 태그가 추가되지 않음
1. CloudTrail이 활성화되어 있는지 확인
2. EventBridge 규칙이 제대로 설정되었는지 확인
3. SQS에 메시지가 들어오는지 확인
4. Lambda에 필요한 권한이 있는지 확인
