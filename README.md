# Cloud Issue Tracker

Starter application used across the Cloud Computing and Cloud Security labs.

The application does three things: create an issue, view all issues, and change an issue
status. Each lab moves those same three operations further into the cloud without changing
the API contract.

## Lab 1

- Development environment verified
- Static HTML structure created
- CSS interface created
- Git repository prepared

## Lab 2 -- Interactive Frontend

The browser holds the issues in a JavaScript array and renders them with the DOM API. Data
lives only in browser memory, so refreshing the page loses every issue.

## Lab 3 -- Application and API Design

The Cloud Issue Tracker now has a documented three-layer architecture and a REST API contract
for create, view and status-change operations. The backend project is initialised and its data
service reads and writes issues in `backend/data/issues.json`. See the files in `/docs` before
implementing the API routes.

- `docs/lab-03-architecture.md` -- layers, request flow and the trust boundary
- `docs/api-contract.md` -- data dictionary, the three endpoints and the error shape
- `docs/api-test-plan.md` -- the test matrix, written before the API existed

## Lab 4 -- The REST API with Node.js and Express

An Express server implements the contract exactly: routes map paths to controller functions,
the controller validates every request at the trust boundary, and the service reads and writes
the data. Errors use one JSON shape, and unexpected failures become a 500 without leaking
internal details.

- `backend/routes/issues.js` -- method + path only
- `backend/controllers/issues.js` -- validation and HTTP responses
- `backend/services/jsonIssueService.js` -- reads and writes the JSON file
- Settings come from `backend/.env`; copy `backend/.env.example` to start

## Lab 5 -- Frontend + Backend, Vercel and Neon

The frontend no longer keeps its own copy of the data. It calls the API with `fetch()`, and the
API is the single source of truth. Storage moves from the JSON file to a managed Postgres
database on Neon, without changing the routes or the controller.

- `frontend/js/config.js` -- the API address, the only file that changes per environment
- `backend/services/issueService.js` -- chooses the store from `DATABASE_URL` / `DYNAMODB_TABLE`
- `backend/services/neonIssueService.js` -- the same three functions, backed by SQL
- `backend/db/schema.sql` -- run this once in the Neon SQL Editor
- `frontend/vercel.json` -- Content-Security-Policy and other browser security headers

## Lab 7 -- Lambda, DynamoDB, IAM, API Gateway and S3

The same Express app runs as an AWS Lambda function. `serverless-http` translates the Lambda
event into an Express request, so the routes, the validation and the status codes are
unchanged. Issues live in a DynamoDB table, an IAM role grants least-privilege access to that
one table, API Gateway gives the function a public address, and S3 serves the website.

- `backend/app.js` -- the Express app, exported without `app.listen()`
- `backend/server.js` -- starts it on your PC
- `backend/lambda.js` -- the Lambda entry point (`handler = lambda.handler`)
- `backend/services/dynamoIssueService.js` -- Scan / Put / Update instead of file reads
- `backend/events/` -- saved request events for testing the function
- `infra/iam/`, `infra/dynamodb/`, `infra/s3/` -- the policies and seed data
- `npm run zip` -- builds `backend/lambda.zip` (never includes `.env`)

## Running it locally

Two terminals, from the repository root.

Backend:

```
cd backend
npm install
cp .env.example .env
npm run dev
```

Frontend:

```
cd frontend
npm install
npm start
```

Open <http://localhost:8080>. The API runs on <http://localhost:3000>.

On startup the backend prints which store it is using:

| Printed | Meaning |
|---|---|
| `Issue storage: local JSON file` | `DATABASE_URL` and `DYNAMODB_TABLE` are both empty |
| `Issue storage: Neon Postgres (DATABASE_URL)` | `DATABASE_URL` is set |
| `Issue storage: DynamoDB table CloudIssues` | `DYNAMODB_TABLE` is set |

## Repository layout

```
frontend/        static site: index.html, css/, js/config.js, js/app.js
backend/
  app.js         the Express app
  server.js      starts it locally
  lambda.js      runs it on AWS Lambda
  controllers/   validation and HTTP responses
  routes/        method + path
  services/      storage: json / neon / dynamo, chosen by issueService.js
  data/          the Lab 4 JSON store
  db/            Neon schema
  events/        saved Lambda test events
  scripts/       zip.js builds the deployment package
docs/            architecture, API contract, test plan, deployment record
evidence/        Postman collection and screenshots
infra/           IAM policies, DynamoDB seed item, S3 bucket policy
```

## Secrets

`backend/.env` holds `DATABASE_URL` and is listed in `.gitignore`, so it is never committed.
`backend/.env.example` lists the same setting names with empty values and is committed.
Treat a connection string like a password: it goes in `.env` on your machine and in the
hosting dashboard, never in code, a screenshot or a commit.
