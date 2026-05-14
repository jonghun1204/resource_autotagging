import json
import boto3
from botocore.exceptions import ClientError

# 재시도 가능한 에러 코드
RETRYABLE_ERROR_CODES = [
    "ResourceNotFoundException",
    "InvalidParameterValue",
    "Throttling",
]


def lambda_handler(event, context):
    for record in event["Records"]:
        try:
            message_body = json.loads(record["body"])
            detail = message_body.get("detail", {})

            # errorCode가 있다면 태깅 중단
            error_code = detail.get("errorCode")
            if error_code:
                error_msg = detail.get("errorMessage", "")
                print(
                    f"[SKIP] {error_code} 에러로 리소스 생성 실패. 다음 레코드 진행: {error_msg}"
                )
                continue

            # 사용자 정보 추출
            user_identity = detail.get("userIdentity", {})
            identity_type = user_identity.get("type", "")
            event_source = detail.get("eventSource", "")
            user_name = user_identity.get("userName", "")

            # Cloud9 EC2 인스턴스 생성의 경우 특별 처리
            if identity_type == "AssumedRole" and event_source == "ec2.amazonaws.com":
                tags = (
                    detail.get("requestParameters", {})
                    .get("tagSpecificationSet", {})
                    .get("items", [{}])[0]
                    .get("tags", [])
                )
                user_id = next(
                    (tag["value"] for tag in tags if tag["key"] == "aws:cloud9:owner"),
                    None,
                )
                user_name = get_username_by_userId(user_id)

            group = find_iam_groups(user_name)

            tags = [
                {"Key": "group", "Value": group},
                {"Key": "username", "Value": user_name},
            ]

            tag_resource(detail, tags)

        except Exception as e:
            print(f"[ERROR] 오류 발생: {str(e)}")
            raise


def get_username_by_userId(user_id):
    iam = boto3.client("iam")
    try:
        paginator = iam.get_paginator("list_users")
        for page in paginator.paginate():
            for user in page["Users"]:
                if user["UserId"] == user_id:
                    return user["UserName"]
    except Exception as e:
        print(f"[ERROR] UserId 조회 중 오류 발생: {str(e)}")
        return "Unknown"


def find_iam_groups(user_name):
    try:
        iam_client = boto3.client("iam")
        response = iam_client.list_groups_for_user(UserName=user_name)
        groups = response.get("Groups", [])

        if len(groups) == 0:
            return "None"
        elif len(groups) == 1:
            return groups[0]["GroupName"]

        oldest_group = min(groups, key=lambda x: x["CreateDate"])
        if "-" in user_name:
            prefix = user_name.rsplit("-", 1)[0]
            matching_groups = [
                group for group in groups if group["GroupName"].startswith(prefix)
            ]
            if matching_groups:
                return matching_groups[0]["GroupName"]

        return oldest_group["GroupName"]
    except ClientError as e:
        print(f"[ERROR] IAM 그룹 조회 중 오류 발생: {str(e)}")
        return "None"


def tag_resource(detail, tags):
    event_source = detail.get("eventSource", "")
    event_region = detail.get("awsRegion", "")
    resource_info = extract_resource_info(detail)

    if not resource_info:
        print("[ERROR] 리소스 정보를 찾을 수 없음")
        raise Exception("리소스 정보를 찾을 수 없음 - 재시도 필요")

    try:
        service = event_source.split(".")[0]

        if service != "elasticloadbalancing":
            client = boto3.client(service, region_name=event_region)

        if service == "ec2":
            client.create_tags(Resources=[resource_info["id"]], Tags=tags)
        elif service == "cloud9":
            client.tag_resource(ResourceARN=resource_info["arn"], Tags=tags)
        elif service == "lambda":
            client.tag_resource(
                Resource=resource_info["arn"],
                Tags=dict((t["Key"], t["Value"]) for t in tags),
            )
        elif service in ["sns", "dynamodb", "ecs"]:
            client.tag_resource(ResourceArn=resource_info["arn"], Tags=tags)
        elif service == "ecr":
            client.tag_resource(resourceArn=resource_info["arn"], tags=tags)
        elif service == "s3":
            client.put_bucket_tagging(
                Bucket=resource_info["id"], Tagging={"TagSet": tags}
            )
        elif service == "rds":
            client.add_tags_to_resource(ResourceName=resource_info["arn"], Tags=tags)
        elif service == "sqs":
            client.tag_queue(
                QueueUrl=resource_info["url"],
                Tags=dict((t["Key"], t["Value"]) for t in tags),
            )
        elif service == "sagemaker":
            client.add_tags(ResourceArn=resource_info["arn"], Tags=tags)
        elif service == "cloudfront":
            client.tag_resource(
                Resource=resource_info["arn"],
                Tags={"Items": [{"Key": t["Key"], "Value": t["Value"]} for t in tags]},
            )
        elif service == "apigateway":
            if resource_info["type"] == "Api":
                client = boto3.client("apigatewayv2", region_name=event_region)
                client.tag_resource(
                    ResourceArn=resource_info["arn"],
                    Tags=dict((t["Key"], t["Value"]) for t in tags),
                )
            elif resource_info["type"] == "RestApi":
                client.tag_resource(
                    resourceArn=resource_info["arn"],
                    tags=dict((t["Key"], t["Value"]) for t in tags),
                )
        elif service == "elasticloadbalancing":
            if resource_info["type"] == "classic":
                elb_client = boto3.client("elb", region_name=event_region)
                elb_client.add_tags(LoadBalancerNames=[resource_info["id"]], Tags=tags)
            else:
                elbv2_client = boto3.client("elbv2", region_name=event_region)
                elbv2_client.add_tags(ResourceArns=[resource_info["arn"]], Tags=tags)
        elif service == "iam":
            if resource_info["type"] == "Role":
                client.tag_role(RoleName=resource_info["id"], Tags=tags)
            elif resource_info["type"] == "Policy":
                client.tag_policy(PolicyArn=resource_info["arn"], Tags=tags)

        print(f"[SUCCESS] 태그 지정 성공: {event_region} - {service} - {resource_info}")
        print(f"[SUCCESS] 적용된 태그: {tags}")

    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "")
        print(f"[ERROR] 태그 지정 중 오류 발생: {error_code} - {str(e)}")

        # 재시도 가능한 에러
        if error_code in RETRYABLE_ERROR_CODES:
            print(f"[RETRY] 재시도 가능한 에러 - SQS가 재시도합니다")
            raise
        else:
            print(f"[SKIP] 재시도 불가능한 에러 - 건너뜀")


def extract_resource_info(detail):
    request_params = detail.get("requestParameters", {})
    response_elements = detail.get("responseElements", {})

    event_source = detail.get("eventSource", "")
    region = detail.get("awsRegion", "")
    account_id = detail.get("userIdentity", {}).get("accountId", "")

    if "ec2.amazonaws.com" in event_source:
        if detail.get("eventName") == "CreateSecurityGroup":
            group_id = response_elements["groupId"]
            return {"id": group_id}
        elif detail.get("eventName") == "AllocateAddress":
            allocation_id = response_elements["allocationId"]
            return {"id": allocation_id}
        elif "instancesSet" in response_elements:
            instance_id = response_elements["instancesSet"]["items"][0]["instanceId"]
            return {"id": instance_id}
        elif detail.get("eventName") == "CreateKeyPair":
            keypair_id = response_elements["keyPairId"]
            return {"id": keypair_id}
        elif detail.get("eventName") == "AuthorizeSecurityGroupIngress":
            security_group_rule_id = response_elements["securityGroupRuleSet"]["items"][
                0
            ]["securityGroupRuleId"]
            return {"id": security_group_rule_id}
    elif "cloud9.amazonaws.com" in event_source:
        # null 체크
        if response_elements is None:
            print(
                f"[SKIP] {request_params}의 responseElements가 null입니다. 다음 이벤트에서 처리됩니다."
            )
            return None
        environment_id = response_elements["environmentId"]
        return {
            "arn": f"arn:aws:cloud9:{region}:{account_id}:environment:{environment_id}"
        }
    elif "lambda.amazonaws.com" in event_source:
        function_arn = response_elements["functionArn"]
        return {"arn": function_arn}
    elif "s3.amazonaws.com" in event_source:
        bucket_name = request_params["bucketName"]
        return {"id": bucket_name}
    elif "rds.amazonaws.com" in event_source:
        if detail.get("eventName") == "CreateDBCluster":
            db_arn = response_elements["dBClusterArn"]
        else:
            db_arn = response_elements["dBInstanceArn"]
        return {"arn": db_arn}
    elif "dynamodb.amazonaws.com" in event_source:
        table_arn = response_elements["tableDescription"]["tableArn"]
        return {"arn": table_arn}
    elif "sns.amazonaws.com" in event_source:
        topic_arn = response_elements["topicArn"]
        return {"arn": topic_arn}
    elif "sqs.amazonaws.com" in event_source:
        queue_url = response_elements["queueUrl"]
        return {"url": queue_url}
    elif "sagemaker.amazonaws.com" in event_source:
        notebook_arn = response_elements["notebookInstanceArn"]
        return {"arn": notebook_arn}
    elif "cloudfront.amazonaws.com" in event_source:
        distribution_arn = response_elements["distribution"]["aRN"]
        return {"arn": distribution_arn}
    elif "ecs.amazonaws.com" in event_source:
        cluster_arn = response_elements["cluster"]["clusterArn"]
        return {"arn": cluster_arn}
    elif "ecr.amazonaws.com" in event_source:
        repository_arn = response_elements["repository"]["repositoryArn"]
        return {"arn": repository_arn}
    elif "apigateway.amazonaws.com" in event_source:
        if detail.get("eventName") in ["CreateApi", "ImportApi"]:
            if detail.get("eventName") == "CreateApi":
                api_id = response_elements["apiId"]
            else:
                api_endpoint = response_elements["apiEndpoint"]
                api_id = api_endpoint.split("//")[1].split(".")[0]
            return {
                "type": "Api",
                "arn": f"arn:aws:apigateway:{region}::/apis/{api_id}",
            }
        elif detail.get("eventName") == "CreateRestApi":
            restapi_id = response_elements["restapiUpdate"]["restApiId"]
            return {
                "type": "RestApi",
                "arn": f"arn:aws:apigateway:{region}::/restapis/{restapi_id}",
            }
    elif "elasticloadbalancing.amazonaws.com" in event_source:
        if detail.get("eventName") == "CreateLoadBalancer":
            lb_type = response_elements.get("loadBalancers", [{}])[0].get("type", "")
            if lb_type in ["application", "network", "gateway"]:
                elb_arn = response_elements["loadBalancers"][0]["loadBalancerArn"]
                return {"type": "elb", "arn": elb_arn}
            else:
                elb_name = request_params["loadBalancerName"]
                return {"type": "classic", "id": elb_name}
        elif detail.get("eventName") == "CreateTargetGroup":
            targetgroup_arn = response_elements["targetGroups"][0]["targetGroupArn"]
            return {"type": "target", "arn": targetgroup_arn}
        elif detail.get("eventName") == "CreateListener":
            listener_arn = response_elements["listeners"][0]["listenerArn"]
            return {"type": "listeners", "arn": listener_arn}
    elif "iam.amazonaws.com" in event_source:
        if "roleName" in request_params:
            role_name = request_params["roleName"]
            return {"type": "Role", "id": role_name}
        elif "policyName" in request_params:
            policy_arn = response_elements["policy"]["arn"]
            return {"type": "Policy", "arn": policy_arn}
    return None
