#!/usr/bin/env bash
# Lab 7: test the API, CORS and the website files in one go.
#   bash infra/check-lab7.sh          -> Floci
#   bash infra/check-lab7.sh aws      -> real AWS (after infra/deploy-aws.sh)
# Every FAIL line is followed by a hint telling you what to fix.

TARGET="${1:-floci}"
cd "$(dirname "$0")/.." || exit 1
. infra/lab7-vars.sh "$TARGET" > /dev/null

if [ "$TARGET" = "aws" ]; then
  ORIGIN="http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com"
  WEB_BASE="$ORIGIN"
else
  ORIGIN="http://localhost:4566"
  WEB_BASE="http://localhost:4566/$BUCKET"
fi

PASS=0; FAIL=0
# Temp files inside the project (Git Bash + MSYS_NO_PATHCONV=1 breaks /tmp paths for curl)
TMP="out/.check-lab7"
mkdir -p "$TMP"
pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1"; echo "     -> $2"; FAIL=$((FAIL + 1)); }

# req METHOD URL [extra curl args...] : sets CODE, BODY, HEAD
req() {
  local method="$1" url="$2"; shift 2
  CODE=$(curl -s -X "$method" -o "$TMP/body" -D "$TMP/head" -w '%{http_code}' --max-time 30 "$@" "$url")
  BODY=$(cat "$TMP/body" 2>/dev/null)
  HEAD=$(tr -d '\r' < "$TMP/head" 2>/dev/null)
}

echo "Checking Lab 7 on $TARGET"
echo "API:     ${API_URL:-(none)}"
echo "Website: $WEB_BASE/index.html"
echo

if [ -z "$API_URL" ]; then
  echo "FAIL no API named cloud-issue-http-api"
  echo "     -> Do Part 3 (create the API), then run this check again."
  exit 1
fi

# T1
req GET "$API_URL/api/health"
if [ "$CODE" = "200" ] && echo "$BODY" | grep -Eq '"runtime": *"lambda"'; then
  pass "T1 GET /api/health answers runtime lambda"
elif [ "$CODE" = "200" ]; then
  fail "T1 GET /api/health answers 200 but not runtime lambda: $BODY" \
       "Upload the Lab 7 zip: cd backend && npm run zip && cd .. then aws lambda update-function-code (Part 2)."
elif [ "$CODE" = "404" ]; then
  fail "T1 GET /api/health answers 404" "Route GET /api/health is missing, or the stage \$default was not created (Part 3)."
else
  fail "T1 GET /api/health answers $CODE: $BODY" \
       "500: read the logs (aws logs tail /aws/lambda/cloud-issue-api --since 10m). Other: check add-permission (Part 3)."
fi

# T2
req POST "$API_URL/api/issues" -H 'Content-Type: application/json' \
  -d '{"title":"Checker test issue","description":"Created by check-lab7.sh","priority":"Low"}'
NEW_ID=$(echo "$BODY" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
if [ "$CODE" = "201" ] && [ -n "$NEW_ID" ]; then
  pass "T2 POST a valid issue answers 201 with id $NEW_ID"
else
  fail "T2 POST a valid issue answers $CODE: $BODY" \
       "500: is DYNAMODB_TABLE=CloudIssues still set on the function? (Part 2). 404: route POST /api/issues missing."
fi

# T3
req POST "$API_URL/api/issues" -H 'Content-Type: application/json' \
  -d '{"title":"Hi","description":"Too short and wrong priority","priority":"Critical"}'
if [ "$CODE" = "400" ] && echo "$BODY" | grep -q 'VALIDATION_ERROR'; then
  pass "T3 POST an invalid issue answers 400 VALIDATION_ERROR"
else
  fail "T3 POST an invalid issue answers $CODE: $BODY" "Upload the Lab 7 code (Part 2)."
fi

# T4
req DELETE "$API_URL/api/issues/ISS-101"
# Lambda's own 404s contain an "error" code; API Gateway's do not (body may vary by emulator version)
if [ "$CODE" = "404" ] && ! echo "$BODY" | grep -q '"error"'; then
  pass "T4 DELETE answers 404 Not Found from API Gateway (Lambda never ran)"
elif echo "$BODY" | grep -q '"error"'; then
  fail "T4 DELETE reached Lambda: $BODY" \
       "You have a catch-all route (\$default or ANY). Delete it: only the 6 routes from Part 3 may exist."
else
  fail "T4 DELETE answers $CODE: $BODY" "Expected 404 {\"message\":\"Not Found\"} from API Gateway."
fi

# T5
req OPTIONS "$API_URL/api/issues" -H "Origin: $ORIGIN" \
  -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: content-type'
ALLOW=$(echo "$HEAD" | grep -i '^access-control-allow-origin:' | cut -d' ' -f2-)
if [ "$ALLOW" = "$ORIGIN" ]; then
  pass "T5 OPTIONS from $ORIGIN is allowed by CORS"
else
  fail "T5 OPTIONS from $ORIGIN: Access-Control-Allow-Origin is '${ALLOW:-missing}' (status $CODE)" \
       "Set CORS_ORIGINS=$ORIGIN on the function (no / at the end, Part 2). 404: route OPTIONS /api/issues missing."
fi

# T6
req OPTIONS "$API_URL/api/issues" -H 'Origin: http://evil.example' \
  -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: content-type'
if [ "$CODE" = "000" ]; then
  fail "T6 OPTIONS could not reach the API (status 000)" "Is Floci running? Check: curl $API_URL/api/health"
elif ! echo "$HEAD" | grep -qi '^access-control-allow-origin:'; then
  pass "T6 OPTIONS from http://evil.example gets no Access-Control-Allow-Origin"
else
  fail "T6 OPTIONS from evil.example was allowed" "CORS_ORIGINS must list ONLY your website address, never *."
fi

# View
req GET "$API_URL/api/issues"
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q 'ISS-101'; then
  pass "GET /api/issues answers 200 and contains ISS-101"
else
  fail "GET /api/issues answers $CODE" "ISS-101 missing? Run: bash infra/setup-all.sh (rebuilds Lab 6)."
fi

# Change status
if [ -n "$NEW_ID" ]; then
  req PATCH "$API_URL/api/issues/$NEW_ID/status" -H 'Content-Type: application/json' -d '{"status":"Resolved"}'
  if [ "$CODE" = "200" ] && echo "$BODY" | grep -Eq '"status": *"Resolved"'; then
    pass "PATCH /api/issues/{id}/status answers 200 Resolved"
  else
    fail "PATCH /api/issues/{id}/status answers $CODE: $BODY" "Route PATCH /api/issues/{id}/status missing (Part 3)."
  fi
else
  fail "PATCH /api/issues/{id}/status was skipped" "T2 must pass first."
fi

# Website files
req GET "$WEB_BASE/index.html"
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q 'Cloud Issue Tracker'; then
  pass "the website index.html is served from the bucket"
else
  fail "the website index.html answers $CODE" "Do Part 4: aws s3 mb s3://$BUCKET then the aws s3 sync command."
fi

req GET "$WEB_BASE/css/style.css"
CT=$(echo "$HEAD" | grep -i '^content-type:' | cut -d' ' -f2-)
if [ "$CODE" = "200" ] && echo "$CT" | grep -qi 'text/css'; then
  pass "css/style.css has content type text/css"
else
  fail "css/style.css answers $CODE with content type '${CT:-none}'" \
       "aws s3 cp frontend/css s3://$BUCKET/css --recursive --content-type text/css"
fi

req GET "$WEB_BASE/js/app.js"
CT=$(echo "$HEAD" | grep -i '^content-type:' | cut -d' ' -f2-)
if [ "$CODE" = "200" ] && echo "$CT" | grep -Eqi '(text|application)/javascript'; then
  pass "js/app.js has a JavaScript content type"
else
  fail "js/app.js answers $CODE with content type '${CT:-none}'" \
       "aws s3 cp frontend/js s3://$BUCKET/js --recursive --content-type text/javascript"
fi

req GET "$WEB_BASE/js/config.js"
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q "$API_ID"; then
  if [ "$TARGET" = "aws" ]; then pass "the uploaded config.js sets AWS_API to your API"
  else pass "the uploaded config.js sets FLOCI_API to your API"; fi
else
  fail "the uploaded config.js does not contain your API ID $API_ID" \
       "Paste $API_URL into frontend/js/config.js, run the aws s3 sync command again, then Ctrl + F5."
fi

req GET "$WEB_BASE/.env"
CODE_B=$CODE
req GET "$WEB_BASE/backend/.env"
if [ "$CODE_B" = "000" ] || [ "$CODE" = "000" ]; then
  fail "the .env check could not reach the website (status 000)" "Is Floci running? Open http://localhost:4566/_floci/health"
elif [ "$CODE_B" != "200" ] && [ "$CODE" != "200" ]; then
  pass "no .env in the website (answer $CODE_B)"
else
  fail "a .env file is PUBLIC in the bucket" \
       "Delete it now: aws s3 rm s3://$BUCKET/.env ; aws s3 rm s3://$BUCKET/backend --recursive. Only sync the frontend folder."
fi

rm -rf "$TMP"
echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
