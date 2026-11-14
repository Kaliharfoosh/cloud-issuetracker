#!/usr/bin/env bash
# OPTIONAL: delete everything infra/deploy-aws.sh created in your real AWS account.
#   bash infra/destroy-aws.sh <student-id>
STUDENT_ID="${1:-}"
[ -z "$STUDENT_ID" ] && { echo "Usage: bash infra/destroy-aws.sh <student-id>"; exit 1; }
cd "$(dirname "$0")/.." || exit 1
unset AWS_PROFILE
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 AWS_PAGER="" MSYS_NO_PATHCONV=1
ACCOUNT=$(aws sts get-caller-identity --query Account --output text) || exit 1
[ "$ACCOUNT" = "000000000000" ] && { echo "This is Floci. Use infra/reset-lab7.sh instead."; exit 1; }

read -r -p "Delete the Lab 7 resources in AWS account $ACCOUNT? (yes/no) " OK
[ "$OK" = "yes" ] || { echo "Nothing deleted."; exit 0; }

BUCKET="cloud-issue-web-$STUDENT_ID"
aws s3 rb "s3://$BUCKET" --force > /dev/null 2>&1 && echo "deleted bucket $BUCKET"
for ID in $(aws apigatewayv2 get-apis --query "Items[?Name=='cloud-issue-http-api'].ApiId" --output text); do
  aws apigatewayv2 delete-api --api-id "$ID" && echo "deleted API $ID"
done
aws lambda delete-function --function-name cloud-issue-api 2>/dev/null && echo "deleted function cloud-issue-api"
aws iam delete-role-policy --role-name cloud-issue-api-role --policy-name issues-table-access 2>/dev/null
aws iam delete-role --role-name cloud-issue-api-role 2>/dev/null && echo "deleted role cloud-issue-api-role"
aws dynamodb delete-table --table-name CloudIssues > /dev/null 2>&1 && echo "deleted table CloudIssues"
aws logs delete-log-group --log-group-name /aws/lambda/cloud-issue-api 2>/dev/null && echo "deleted log group"
rm -f infra/.lab7-aws.env
sed -i "s#^const AWS_API = .*#const AWS_API = 'https://YOUR-AWS-API-ID.execute-api.us-east-1.amazonaws.com';#" frontend/js/config.js
echo "Done. Check the AWS Console (Billing) to be sure nothing is left."
