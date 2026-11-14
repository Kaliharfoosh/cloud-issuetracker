# API Test Plan

T01-T09 were written in Lab 3, **before** the API existed, to define what "working correctly"
would mean. T10-T12 were added in Lab 4 so that the plan covers every error in the contract.

Every test traces back to a rule in `api-contract.md`, and the plan contains both positive
cases (T01, T02, T05, T08, T09) and negative cases (T03, T04, T06, T07, T10, T11, T12).

## Results

Run against `http://localhost:3000` with the API backed by **Neon Postgres** (Lab 5 Part 9).
The same plan was run against the Lab 4 JSON file store first, and every status code was
identical, which is what Lab 5 Part 9 Step 2 requires.

| Test ID | Request | Expected Result | Actual Result | Pass/Fail |
|---|---|---|---|---|
| T01 | GET /api/issues | 200; JSON array returned. | 200; array with 1 issue | Pass |
| T02 | POST valid title, description, priority | 201; complete created issue returned. | 201; server-generated id `1b35102d-...`, status Open, createdAt from the database | Pass |
| T03 | POST missing title | 400; VALIDATION_ERROR. | 400; VALIDATION_ERROR: "Title is required." | Pass |
| T04 | POST invalid priority = Critical | 400; VALIDATION_ERROR. | 400; VALIDATION_ERROR: "Priority must be Low, Medium or High." | Pass |
| T05 | PATCH existing issue status = Resolved | 200; returned status is Resolved. | 200; complete issue returned with status Resolved | Pass |
| T06 | PATCH status = Deleted | 400; VALIDATION_ERROR. | 400; VALIDATION_ERROR: "Status must be Open or Resolved." | Pass |
| T07 | PATCH unknown issue ID | 404; ISSUE_NOT_FOUND. | 404; ISSUE_NOT_FOUND: "Issue not found." | Pass |
| T08 | GET when no issues exist | 200; empty JSON array. | 200; `[]` | Pass |
| T09 | Send unexpected extra server-owned fields | Server ignores/rejects according to contract; client cannot choose authoritative id/status/createdAt. | 201; id is a new server UUID (not `HACKED-1`), status Open (not Resolved), createdAt is now (not 2000-01-01) | Pass |
| T10 | POST with Content-Type: text/plain | 415; UNSUPPORTED_MEDIA_TYPE. | 415; UNSUPPORTED_MEDIA_TYPE: "Content-Type must be application/json." | Pass |
| T11 | POST malformed JSON (trailing comma) | 400; VALIDATION_ERROR. | 400; VALIDATION_ERROR: "Request body is not valid JSON." The server kept running. | Pass |
| T12 | PATCH /api/fake-url (unknown route) | 404; ROUTE_NOT_FOUND. | 404; ROUTE_NOT_FOUND: "Route not found." | Pass |

**Result: 12 passed, 0 failed.**

## Additional checks

These are not numbered tests in the contract, but they were verified in the same run.

| Check | Expected | Actual | Pass/Fail |
|---|---|---|---|
| PATCH a well-formed UUID that has no row | 404; ISSUE_NOT_FOUND, not 500 | 404; ISSUE_NOT_FOUND | Pass |
| GET /api/health (Lab 5) | 200; status ok | 200; `{"status":"ok","environment":"development","runtime":"pc"}` | Pass |
| GET /api/issues/count (Lab 7) | 200; `{ "count": n }` | 200; `{"count":2}` | Pass |

## Which file produces each status code

| Status | Error code | Produced by |
|---|---|---|
| 200 | (none) | `controllers/issues.js`: `listIssues`, `countIssues`, `updateIssueStatus` |
| 201 | (none) | `controllers/issues.js`: `createIssue` |
| 400 | VALIDATION_ERROR | `controllers/issues.js` when a field rule fails, or the error handler in `app.js` when the body is not valid JSON |
| 404 | ISSUE_NOT_FOUND | `controllers/issues.js`: `updateIssueStatus` when the service returns `null` |
| 404 | ROUTE_NOT_FOUND | The route-not-found middleware in `app.js` |
| 415 | UNSUPPORTED_MEDIA_TYPE | `controllers/issues.js`: `createIssue` and `updateIssueStatus` |
| 500 | INTERNAL_ERROR | The error handler in `app.js` |
