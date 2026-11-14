#!/usr/bin/env bash
# OPTIONAL Lab 7 Part 6: deploy the same app to YOUR OWN real AWS account.
#   unset AWS_PROFILE
#   bash infra/deploy-aws.sh <student-id>      e.g. bash infra/deploy-aws.sh 2023170123
#   bash infra/check-lab7.sh aws
#   bash infra/destroy-aws.sh <student-id>     when you are done (stops all costs)
# Needs credentials in ~/.aws/credentials under [default]. Region: us-east-1.
set -u
STUDENT_ID="${1:-}"
if ! [[ "$STUDENT_ID" =~ ^[a-z0-9-]{3,30}$ ]]; then
  echo "Usage: bash infra/deploy-aws.sh <student-id>   (lowercase letters, digits, hyphens)"; exit 1
fi
cd "$(dirname "$0")/.." || exit 1
unset AWS_PROFILE
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 AWS_PAGER="" MSYS_NO_PATHCONV=1
REGION=us-east-1
FN=cloud-issue-api
ROLE=cloud-issue-api-role
TABLE=CloudIssues
BUCKET="cloud-issue-web-$STUDENT_ID"
WEB_URL="http://$BUCKET.s3-website-$REGION.amazonaws.com"

ACCOUNT=$(aws sts get-caller-identity --query Account --output text) || {
  echo "No AWS credentials. Put your keys in ~/.aws/credentials under [default]."; exit 1; }
if [ "$ACCOUNT" = "000000000000" ]; then
  echo "This is Floci, not real AWS. Run: unset AWS_PROFILE"; exit 1
fi
echo "Real AWS account $ACCOUNT, region $REGION, bucket $BUCKET"
echo "STUDENT_ID=$STUDENT_ID" > infra/.lab7-aws.env

echo "1/6 DynamoDB table + ISS-101"
if ! aws dynamodb describe-table --table-name $TABLE > /dev/null 2>&1; then
  aws dynamodb create-table --table-name $TABLE \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST > /dev/null
  aws dynamodb wait table-exists --table-name $TABLE
fi
aws dynamodb put-item --table-name $TABLE --item file://infra/dynamodb/seed-item.json

echo "2/6 Least-privilege role (only this table, only its own log group)"
TMP="out/.deploy-aws"; mkdir -p "$TMP"   # inside the project: /tmp breaks in Git Bash
cat > "$TMP/policy.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["dynamodb:Scan", "dynamodb:PutItem", "dynamodb:UpdateItem"],
      "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT:table/$TABLE" },
    { "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:$REGION:$ACCOUNT:log-group:/aws/lambda/$FN:*" }
  ]
}
JSON
NEW_ROLE=0
if ! aws iam get-role --role-name $ROLE > /dev/null 2>&1; then
  aws iam create-role --role-name $ROLE \
    --assume-role-policy-document file://infra/iam/trust-policy.json > /dev/null
  NEW_ROLE=1
fi
aws iam put-role-policy --role-name $ROLE --policy-name issues-table-access \
  --policy-document "file://$TMP/policy.json"
if [ $NEW_ROLE = 1 ]; then echo "  waiting 15 s for the new role to reach Lambda"; sleep 15; fi

echo "3/6 Lambda function"
(cd backend && npm install --no-audit --no-fund --loglevel=error && npm run zip --silent) || exit 1
ENV_VARS="Variables={DYNAMODB_TABLE=$TABLE,CORS_ORIGINS=$WEB_URL,NODE_ENV=production}"
if aws lambda get-function --function-name $FN > /dev/null 2>&1; then
  aws lambda update-function-code --function-name $FN --zip-file fileb://backend/lambda.zip > /dev/null
  aws lambda wait function-updated-v2 --function-name $FN
  aws lambda update-function-configuration --function-name $FN --handler lambda.handler \
    --environment "$ENV_VARS" > /dev/null
  aws lambda wait function-updated-v2 --function-name $FN
else
  aws lambda create-function --function-name $FN --runtime nodejs24.x --handler lambda.handler \
    --role arn:aws:iam::$ACCOUNT:role/$ROLE --zip-file fileb://backend/lambda.zip \
    --timeout 10 --environment "$ENV_VARS" > /dev/null
  aws lambda wait function-active-v2 --function-name $FN
fi

echo "4/6 API Gateway (6 routes, stage \$default)"
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='cloud-issue-http-api'].ApiId | [0]" --output text)
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  API_ID=$(aws apigatewayv2 create-api --name cloud-issue-http-api --protocol-type HTTP --query ApiId --output text)
  INTEGRATION_ID=$(aws apigatewayv2 create-integration --api-id $API_ID \
    --integration-type AWS_PROXY --payload-format-version 2.0 \
    --integration-uri arn:aws:lambda:$REGION:$ACCOUNT:function:$FN \
    --query IntegrationId --output text)
  for ROUTE in "GET /api/health" "GET /api/issues" "POST /api/issues" \
    "PATCH /api/issues/{id}/status" "OPTIONS /api/issues" "OPTIONS /api/issues/{id}/status"; do
    aws apigatewayv2 create-route --api-id $API_ID --route-key "$ROUTE" \
      --target integrations/$INTEGRATION_ID > /dev/null
  done
  aws apigatewayv2 create-stage --api-id $API_ID --stage-name '$default' --auto-deploy > /dev/null
fi
aws lambda add-permission --function-name $FN --statement-id apigw-invoke \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT:$API_ID/*" > /dev/null 2>&1
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com"

echo "5/6 Website bucket (public on purpose: read-only bucket policy)"
if ! aws s3api head-bucket --bucket "$BUCKET" > /dev/null 2>&1; then
  aws s3api create-bucket --bucket "$BUCKET" > /dev/null || {
    echo "Bucket name taken or refused. Try another student id."; exit 1; }
fi
# Allow a bucket POLICY to make it public; ACLs stay blocked.
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
sed "s#arn:aws:s3:::cloud-issue-web/\*#arn:aws:s3:::$BUCKET/*#" infra/s3/public-read-policy.json > "$TMP/bucket-policy.json"
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$TMP/bucket-policy.json" || {
  echo "Bucket policy refused: your ACCOUNT blocks public buckets (S3 > Block Public Access settings for this account)."; exit 1; }
aws s3 website "s3://$BUCKET" --index-document index.html

echo "6/6 Upload the website"
sed -i "s#^const AWS_API = .*#const AWS_API = '$API_URL';#" frontend/js/config.js
aws s3 sync frontend "s3://$BUCKET" \
  --exclude "package.json" --exclude "vercel.json" --exclude "node_modules/*" > /dev/null
aws s3 cp frontend/css "s3://$BUCKET/css" --recursive --content-type text/css > /dev/null
aws s3 cp frontend/js "s3://$BUCKET/js" --recursive --content-type text/javascript > /dev/null
rm -rf "$TMP"

echo
echo "API:     $API_URL/api/health"
echo "Website: $WEB_URL"
echo "Check:   bash infra/check-lab7.sh aws"
echo "Delete:  bash infra/destroy-aws.sh $STUDENT_ID   (do it, so nothing keeps costing money)"
