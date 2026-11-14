#!/usr/bin/env bash
# Lab 7: catch up. Does Parts 2, 3 and 4 on Floci in one go (and Lab 6 first if it is missing).
# Run from the project folder in Git Bash:   bash infra/setup-lab7.sh
# Use it if you fell behind. You still need to understand every step for the practical.
export AWS_PROFILE=floci AWS_PAGER="" MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.." || exit 1
ACCOUNT=000000000000
REGION=us-east-1
BUCKET=cloud-issue-web
FN=cloud-issue-api

if ! curl -s -o /dev/null http://localhost:4566/_floci/health; then
  echo "Floci is not running. Start Docker Desktop, then:"
  echo "  docker compose -f infra/floci/docker-compose.yml up -d"
  exit 1
fi

echo "Part 1: check Lab 6"
if ! aws dynamodb describe-table --table-name CloudIssues > /dev/null 2>&1 \
   || ! aws lambda get-function --function-name $FN > /dev/null 2>&1; then
  echo "  Lab 6 is missing: rebuilding it with infra/setup-all.sh"
  bash infra/setup-all.sh || exit 1
fi

echo "Part 2: upload the Lab 7 code and settings"
(cd backend && npm install --no-audit --no-fund --loglevel=error && npm run zip --silent) || exit 1
aws lambda update-function-code --function-name $FN --zip-file fileb://backend/lambda.zip > /dev/null
aws lambda wait function-updated-v2 --function-name $FN
aws lambda update-function-configuration --function-name $FN \
  --handler lambda.handler \
  --environment "Variables={DYNAMODB_TABLE=CloudIssues,CORS_ORIGINS=http://localhost:4566,NODE_ENV=production}" > /dev/null
aws lambda wait function-updated-v2 --function-name $FN

echo "Part 3: API Gateway"
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
      --target integrations/$INTEGRATION_ID --query RouteKey --output text | sed 's/^/  route: /'
  done
  aws apigatewayv2 create-stage --api-id $API_ID --stage-name '$default' --auto-deploy > /dev/null
else
  echo "  API cloud-issue-http-api already exists ($API_ID): reusing it"
fi
aws lambda add-permission --function-name $FN --statement-id apigw-invoke \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT:$API_ID/*" > /dev/null 2>&1
API_URL=http://$API_ID.execute-api.localhost.floci.io:4566
echo "  API_URL=$API_URL"

echo "Part 4: website on S3"
sed -i "s#^const FLOCI_API = .*#const FLOCI_API = '$API_URL';#" frontend/js/config.js
aws s3 mb s3://$BUCKET > /dev/null 2>&1
aws s3 sync frontend s3://$BUCKET \
  --exclude "package.json" --exclude "vercel.json" --exclude "node_modules/*" > /dev/null
aws s3 cp frontend/css s3://$BUCKET/css --recursive --content-type text/css > /dev/null
aws s3 cp frontend/js s3://$BUCKET/js --recursive --content-type text/javascript > /dev/null
aws s3 ls s3://$BUCKET --recursive

echo
echo "Website: http://localhost:4566/$BUCKET/index.html"
echo "In your Git Bash window run:  source infra/lab7-vars.sh"
echo
bash infra/check-lab7.sh
