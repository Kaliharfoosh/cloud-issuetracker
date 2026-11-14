# Lab 3 -- Cloud Issue Tracker Architecture

## 1. Application Goal

The Cloud Issue Tracker lets a user report a simple technical issue, see every issue that has
been reported, and mark an issue as resolved or reopen it.

In Lab 2 the whole application lived in the browser. The issue list was a JavaScript array in
browser memory, so refreshing the page lost every issue that had been created and no second
user could ever see the same list.

The goal of this design is to split that single program into three layers, each with one
responsibility, so that the data outlives the browser tab and can be shared:

- **Frontend (browser)** -- presents data and collects user actions.
- **REST API** -- applies server-side rules and exposes a small set of controlled operations.
- **Data layer** -- stores the application state.

## 2. Functional Scope

The application performs exactly three operations:

- Create an issue.
- View all issues.
- Change an issue status.

Anything else (deleting issues, editing a title, user accounts, assigning issues) is out of
scope for this design.

Each operation maps to exactly one endpoint:

| Application Function | Method | Endpoint | Meaning |
|---|---|---|---|
| View all issues | GET | `/api/issues` | Retrieve the issue collection. |
| Create an issue | POST | `/api/issues` | Create a new issue in the collection. |
| Change status | PATCH | `/api/issues/{id}/status` | Partially update the status of one issue. |

The URLs are resource nouns, in lowercase and plural. The HTTP method carries the action, so
there is no `/getIssues` or `/createIssue`. `PATCH` is used instead of `PUT` because only the
status field changes, not the whole issue.

## 3. Request Flow

### Create an issue

```
User -> Frontend form -> POST /api/issues -> API validation -> Data layer
Render created issue <- 201 + JSON <-
```

- The user fills in the form (title, description, priority) and clicks Submit.
- The frontend sends `POST /api/issues` with the form data as JSON.
- The API validates the data (title present, length limits, allowed priority). If it is
  invalid, the API stops and returns `400` with an error message. Nothing is saved.
- The data layer stores the issue, gives it an `id` and the status `Open`.
- The API replies `201 Created` and the new issue as JSON.
- The frontend adds the new issue to the list on screen.

### View issues

```
Page load -> GET /api/issues -> API -> Data layer
Render list <- 200 + JSON array <-
```

- The page loads and the frontend sends `GET /api/issues`.
- The API asks the data layer for every stored issue.
- The API replies `200 OK` and the JSON array, which is `[]` when nothing is stored.
- The frontend renders one card per issue, or "No issues yet" when the array is empty.

### Change status

```
Button -> PATCH /api/issues/{id}/status -> API validation -> Data layer
Re-render issue <- 200 + updated JSON <-
```

- The user clicks the status button on one issue.
- The frontend sends `PATCH /api/issues/{id}/status` with a body such as `{"status": "Resolved"}`.
- The API validates two things:
  - the issue `{id}` exists, otherwise `404 Not Found`;
  - the new status is an allowed value, otherwise `400 Bad Request`.
- The data layer updates only the status field of that issue.
- The API replies `200 OK` and the full updated issue as JSON.
- The frontend re-renders that issue with its new status.

## 4. Trust Boundaries

A trust boundary is the line where data stops being controlled by the user and starts being
controlled by the application. Data crossing it must be validated before it is accepted.

```
USER-CONTROLLED SIDE        |        APPLICATION-CONTROLLED SIDE
                            |
Browser input -> HTTP request -> REST API -> Data
                            |
              <- JSON response <-
```

**User-controlled side:** the browser, the form fields, the buttons, and every HTTP request
that leaves the browser. The user can change any of it with browser dev tools, `curl` or
Postman. An HTTP request is therefore untrusted until the API has validated it.

**Application-controlled side:** the REST API and the data layer. Only our own code runs here,
and the data is reachable only through the API.

**The boundary is the HTTP request**, and it follows four rules:

1. The API validates every request. Frontend checks exist only for fast feedback, never for
   security, because requests can come from other programs and not only from our page.
2. The browser never talks to the data layer directly.
3. The API returns only what the frontend needs, and never leaks internal errors or stack
   traces. Unexpected failures become a generic `500 INTERNAL_ERROR`, with the details written
   to the server log only.
4. The frontend shows issue text as plain text, never as HTML, so a title containing markup
   cannot become script in another user's browser.

A direct consequence of this boundary is the ownership rule in the data model: `POST` requests
do not accept `id`, `status` or `createdAt` from the client. Those fields are created and
controlled by the server, so the browser can never choose an authoritative id or backdate an
issue.
