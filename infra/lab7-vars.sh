#!/usr/bin/env bash
# Lab 7: get your IDs back in a new Git Bash window.
#   source infra/lab7-vars.sh          -> Floci (default)
#   source infra/lab7-vars.sh aws      -> real AWS (after infra/deploy-aws.sh)
# Must be SOURCED (not run with bash) so the variables stay in your window.

LAB7_TARGET="${1:-floci}"
export MSYS_NO_PATHCONV=1 AWS_PAGER=""

if [ "$LAB7_TARGET" = "aws" ]; then
  unset AWS_PROFILE
  if [ -f infra/.lab7-aws.env ]; then . infra/.lab7-aws.env; fi
  export AWS_REGION="${AWS_REGION:-us-east-1}"
  BUCKET="cloud-issue-web-${STUDENT_ID:-YOUR-STUDENT-ID}"
else
  export AWS_PROFILE=floci
  BUCKET="cloud-issue-web"
fi

API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='cloud-issue-http-api'].ApiId | [0]" --output text 2>/dev/null)
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  echo "No API named cloud-issue-http-api found ($LAB7_TARGET). Create it first (Part 3)."
  API_ID=""; API_URL=""
else
  if [ "$LAB7_TARGET" = "aws" ]; then
    API_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com"
    WEB_URL="http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com"
  else
    API_URL="http://$API_ID.execute-api.localhost.floci.io:4566"
    WEB_URL="http://localhost:4566/$BUCKET/index.html"
  fi
  INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id "$API_ID" --query "Items[0].IntegrationId" --output text 2>/dev/null)
fi
export API_ID API_URL WEB_URL BUCKET INTEGRATION_ID

echo "Target:  $LAB7_TARGET"
echo "API_ID:  ${API_ID:-(none)}"
echo "API_URL: ${API_URL:-(none)}"
echo "Website: ${WEB_URL:-(none)}"
