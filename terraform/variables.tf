variable "aws_profile" {
  description = "AWS CLI 프로필 이름"
  type        = string
  default     = "default"
}

variable "central_tagging_region" {
  description = "중앙 태깅 리전"
  type        = string
  default     = "us-east-1"
}

variable "source_region_1" {
  description = "첫 번째 태깅 소스 리전 (빈 문자열이면 비활성화)"
  type        = string
  default     = "us-west-2"
}

variable "source_region_2" {
  description = "두 번째 태깅 소스 리전 (빈 문자열이면 비활성화)"
  type        = string
  default     = ""
}

variable "source_region_3" {
  description = "세 번째 태깅 소스 리전 (빈 문자열이면 비활성화)"
  type        = string
  default     = ""
}

variable "source_region_4" {
  description = "네 번째 태깅 소스 리전 (빈 문자열이면 비활성화)"
  type        = string
  default     = ""
}

variable "source_region_5" {
  description = "다섯 번째 태깅 소스 리전 (빈 문자열이면 비활성화)"
  type        = string
  default     = ""
}
