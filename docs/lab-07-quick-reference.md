# Lab 7 Quick Reference: API Gateway + S3 on Floci (and real AWS)

The Word lab sheet has the explanations. This page is the command list.
Run every command in **Git Bash inside the project folder**. Each step can also be done in
**Floci Dash** (http://localhost:4566/_floci/ui).

## Part 1: start Floci and check Lab 6
```bash
docker compose -f infra/floci/docker-compose.yml up -d
export AWS_PROFILE=floci MSYS_NO_PATHCONV=1
aws sts get-caller-identity --query Account --output text                              # 000000000000
aws dynamodb describe-table --table-name CloudIssues --query Table.TableStatus --output text   # ACTIVE
aws lambda get-function --function-name cloud-issue-api --query Configuration.State --output text  # Active
# missing? -> bash infra/setup-all.sh
```

## Part 2: new code and settings
```bash
cd backend && npm install && npm run zip && cd ..
aws lambda update-function-code --function-name cloud-issue-api --zip-file fileb://backend/lambda.zip
aws lambda wait function-updated-v2 --function-name cloud-issue-api
aws lambda update-function-configuration --function-name cloud-issue-api \
  --environment "Variables={DYNAMODB_TABLE=CloudIssues,CORS_ORIGINS=http://localhost:4566,NODE_ENV=production}"
```

## Part 3: API Gateway
```bash
API_ID=$(aws apigatewayv2 create-api --name cloud-issue-http-api \
  --protocol-type HTTP --query ApiId --output text)
INTEGRATION_ID=$(aws apigatewayv2 create-integration --api-id $API_ID \
  --integration-type AWS_PROXY --payload-format-version 2.0 \
  --integration-uri arn:aws:lambda:us-east-1:000000000000:function:cloud-issue-api \
  --query IntegrationId --output text)
echo $API_ID $INTEGRATION_ID

for ROUTE in "GET /api/health" "GET /api/issues" "POST /api/issues" \
  "PATCH /api/issues/{id}/status" \
  "OPTIONS /api/issues" "OPTIONS /api/issues/{id}/status"; do
  aws apigatewayv2 create-route --api-id $API_ID --route-key "$ROUTE" \
    --target integrations/$INTEGRATION_ID --query RouteKey --output text
done

aws apigatewayv2 create-stage --api-id $API_ID --stage-name '$default' --auto-deploy
API_URL=http://$API_ID.execute-api.localhost.floci.io:4566
echo $API_URL

aws lambda add-permission --function-name cloud-issue-api --statement-id apigw-invoke \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$API_ID/*"
```
Test: open `$API_URL/api/health`, then `docs/aws-api-tests.http` (T1 to T6).

## Part 4: website on S3
Paste `$API_URL` into `frontend/js/config.js` (`FLOCI_API`, no `/` at the end), then:
```bash
aws s3 mb s3://cloud-issue-web
aws s3 sync frontend s3://cloud-issue-web \
  --exclude "package.json" --exclude "vercel.json" --exclude "node_modules/*"
aws s3 cp frontend/css s3://cloud-issue-web/css --recursive --content-type text/css
aws s3 cp frontend/js s3://cloud-issue-web/js --recursive --content-type text/javascript
aws s3 ls s3://cloud-issue-web --recursive
bash infra/check-lab7.sh                      # Result: 13 passed, 0 failed
```
Website: http://localhost:4566/cloud-issue-web/index.html

## Part 5: follow one request
```bash
aws dynamodb scan --table-name CloudIssues --query "Items[].[id.S, title.S, status.S]" --output table
aws logs tail /aws/lambda/cloud-issue-api --since 15m --format short
```

## Helpers
```bash
source infra/lab7-vars.sh      # new window: get $API_ID, $API_URL back
bash infra/setup-lab7.sh       # catch up: Parts 2 to 4 in one go
bash infra/reset-lab7.sh       # delete the Lab 7 API and bucket, start again at Part 2
bash infra/setup-all.sh        # rebuild Lab 6 (table, role, function)
bash infra/reset-lab.sh        # delete Lab 6 too
```

## Optional: real AWS (your own account)
```bash
unset AWS_PROFILE
bash infra/deploy-aws.sh <student-id>
bash infra/check-lab7.sh aws
bash infra/destroy-aws.sh <student-id>     # always, when you are done
```

## PowerShell
Use Git Bash for this lab: the helper scripts are bash scripts.
