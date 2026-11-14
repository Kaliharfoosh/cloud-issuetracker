#!/usr/bin/env bash
# Lab 7: delete what Lab 7 created on Floci (API, permission, website bucket) and put the
# function back to its Lab 6 settings. The table and the function (Lab 6) are kept.
# Run from the project folder in Git Bash:   bash infra/reset-lab7.sh   then start again at Part 2.
export AWS_PROFILE=floci AWS_PAGER="" MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.." || exit 1

for ID in $(aws apigatewayv2 get-apis --query "Items[?Name=='cloud-issue-http-api'].ApiId" --output text 2>/dev/null); do
  aws apigatewayv2 delete-api --api-id "$ID" && echo "deleted API $ID"
done
aws lambda remove-permission --function-name cloud-issue-api --statement-id apigw-invoke > /dev/null 2>&1 \
  && echo "removed the API Gateway permission"
aws s3 rb s3://cloud-issue-web --force > /dev/null 2>&1 && echo "deleted bucket cloud-issue-web"
aws lambda update-function-configuration --function-name cloud-issue-api \
  --environment "Variables={DYNAMODB_TABLE=CloudIssues}" > /dev/null 2>&1 \
  && echo "function settings back to Lab 6 (DYNAMODB_TABLE only)"
sed -i "s#^const FLOCI_API = .*#const FLOCI_API = 'http://YOUR-API-ID.execute-api.localhost.floci.io:4566';#" frontend/js/config.js
echo "config.js FLOCI_API back to the placeholder"
echo "Lab 7 reset. Start again from Part 2 (or run: bash infra/setup-lab7.sh)."
