# Lab 7 Deployment Record: API Gateway + S3 (Floci)

Fill this in as you go. It is your evidence for the practical.

**Name:** ____________________ **Student ID:** ____________ **Date:** ____________

## Part 1: Floci and Lab 6

| Check | Result |
|---|---|
| `aws sts get-caller-identity` account | |
| `CloudIssues` table status | |
| `cloud-issue-api` function state | |
| Way used (A Floci Dash / B Git Bash) | |

## Part 2: Lambda code and settings

| Key | Value set |
|---|---|
| `DYNAMODB_TABLE` | |
| `CORS_ORIGINS` | |
| `NODE_ENV` | |

Checked with the other way? (yes/no): ____

## Part 3: API Gateway

| Item | Value |
|---|---|
| API name | cloud-issue-http-api |
| API_ID | |
| API_URL | |
| Number of routes | |
| Stage | $default (auto-deploy) |
| `add-permission` done | |

| Test | Request | Expected | My result |
|---|---|---|---|
| T1 | GET /api/health | 200, runtime: lambda | |
| T2 | POST a valid issue | 201 and a new id | |
| T3 | POST title "Hi", priority "Critical" | 400 VALIDATION_ERROR | |
| T4 | DELETE /api/issues/ISS-101 | 404 {"message":"Not Found"} from API Gateway | |
| T5 | OPTIONS from http://localhost:4566 | Access-Control-Allow-Origin: http://localhost:4566 | |
| T6 | OPTIONS from http://evil.example | no Access-Control-Allow-Origin | |

## Part 4: Website on S3

| Item | Value |
|---|---|
| Bucket | cloud-issue-web |
| Files in bucket (`aws s3 ls`) | |
| Website URL | http://localhost:4566/cloud-issue-web/index.html |
| Header shows | |
| `bash infra/check-lab7.sh` result | ___ passed, ___ failed |

## Part 5: The journey of one POST request (in my own words)

1.
2.
3.
4.
5.

| Evidence | Seen? |
|---|---|
| Network: OPTIONS 204 then POST 201 | |
| Network: OPTIONS then PATCH 200 | |
| New issue in DynamoDB with status Resolved | |
| Log lines for OPTIONS and POST, plus a REPORT line | |
| No log line for T4 (DELETE). Why? | |

## Part 6: Floci vs real AWS

Four things that change on real AWS:

1.
2.
3.
4.

One thing that does not change:

Why a real website bucket needs a bucket policy, and what it allows:

## Screenshots

- [ ] Floci Dash: API Gateway > cloud-issue-http-api > Routes
- [ ] REST Client: T2 201 and T4 404
- [ ] Floci Dash: S3 > cloud-issue-web
- [ ] Website with "API online: lambda (production)"
- [ ] DevTools Network: OPTIONS 204 then POST 201
- [ ] Floci Dash: CloudWatch Logs > /aws/lambda/cloud-issue-api
