// Lab 5: the REST API is now the source of truth (no in-memory issues array).
// API_BASE_URL and API_HEALTH_URL come from js/config.js (loaded first).

const issueForm = document.querySelector('#issue-form');
const titleInput = document.querySelector('#title');
const descriptionInput = document.querySelector('#description');
const priorityInput = document.querySelector('#priority');
const issuesList = document.querySelector('#issues-list');
const issueCount = document.querySelector('#issue-count');
const formMessage = document.querySelector('#form-message');
const apiStatus = document.querySelector('#api-status');

// Send a request, parse the JSON body, and throw if the status is not 2xx
async function apiRequest(url, options = {}) {
  const response = await fetch(url, options);

  let body = null;
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    body = await response.json();
  }

  if (!response.ok) {
    // API errors look like { error: { code, message } } (see docs/api-contract.md)
    const message = body?.error?.message || `Request failed (${response.status})`;
    throw new Error(message);
  }

  return body;
}

function renderIssues(issues) {
  issuesList.replaceChildren();
  issueCount.textContent = issues.length;

  issues.forEach((issue) => {
    const card = document.createElement('article');
    card.className = 'issue-card';

    const heading = document.createElement('h3');
    heading.textContent = issue.title;

    const description = document.createElement('p');
    description.textContent = issue.description;

    const meta = document.createElement('p');
    meta.textContent = `Priority: ${issue.priority} | Status: ${issue.status}`;

    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = issue.status === 'Open' ? 'Mark Resolved' : 'Reopen';
    button.addEventListener('click', () => changeIssueStatus(issue));

    card.append(heading, description, meta, button);
    issuesList.append(card);
  });
}

// View: GET /api/issues
async function loadIssues() {
  try {
    formMessage.textContent = 'Loading issues...';
    const issues = await apiRequest(API_BASE_URL);
    renderIssues(issues);
    formMessage.textContent = '';
  } catch (error) {
    console.error(error);
    formMessage.textContent = `Could not load issues: ${error.message}`;
  }
}

// Create: POST /api/issues
issueForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const payload = {
    title: titleInput.value.trim(),
    description: descriptionInput.value.trim(),
    priority: priorityInput.value
  };

  try {
    formMessage.textContent = 'Submitting issue...';

    await apiRequest(API_BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    issueForm.reset();
    priorityInput.value = 'Medium';
    await loadIssues();
    formMessage.textContent = 'Issue created successfully.';
  } catch (error) {
    console.error(error);
    formMessage.textContent = `Could not create issue: ${error.message}`;
  }
});

// Change status: PATCH /api/issues/{id}/status
async function changeIssueStatus(issue) {
  const nextStatus = issue.status === 'Open' ? 'Resolved' : 'Open';

  try {
    // The status goes in the JSON body (the API contract) and also in the URL as a fallback
    // for emulators that drop PATCH bodies.
    await apiRequest(`${API_BASE_URL}/${issue.id}/status?status=${encodeURIComponent(nextStatus)}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ status: nextStatus })
    });

    await loadIssues();
  } catch (error) {
    console.error(error);
    formMessage.textContent = `Could not update issue: ${error.message}`;
  }
}

// Lab 7: header line, e.g. "API online: lambda (production)"
async function checkApi() {
  try {
    const health = await apiRequest(API_HEALTH_URL);
    apiStatus.textContent = `API online: ${health.runtime || 'unknown'} (${health.environment})`;
    apiStatus.className = 'api-status online';
  } catch (error) {
    console.error(error);
    apiStatus.textContent = 'API not reachable: check FLOCI_API in js/config.js';
    apiStatus.className = 'api-status offline';
  }
}

checkApi();
loadIssues();
