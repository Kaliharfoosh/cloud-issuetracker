// Frontend configuration. This is the ONLY file you edit to point the
// frontend at a different API. Nothing in this file is secret: every visitor
// can read it, so never put DATABASE_URL or any secret key here.

// Lab 7 Part 4: paste your API URL here (no slash at the end).
// Example: 'http://k7c2x9pq1m.execute-api.localhost.floci.io:4566'
const FLOCI_API = 'http://YOUR-API-ID.execute-api.localhost.floci.io:4566';

// Optional real AWS deploy (infra/deploy-aws.sh fills this in for you)
const AWS_API = 'https://YOUR-AWS-API-ID.execute-api.us-east-1.amazonaws.com';

// Lab 5: your Vercel API project
const VERCEL_API = 'https://YOUR-API-PROJECT.vercel.app';

// config.js picks the right API by itself, from the address the page was loaded from:
//   port 4566        -> Floci (website in the S3 bucket on Floci)
//   amazonaws.com    -> real AWS (website in a real S3 bucket)
//   localhost / PC   -> the Express API on your PC (npm run dev, port 3000)
//   anything else    -> Vercel
const { hostname, port } = window.location;
let API_ROOT;
if (port === '4566') {
  API_ROOT = FLOCI_API;
} else if (hostname.endsWith('amazonaws.com')) {
  API_ROOT = AWS_API;
} else if (['localhost', '127.0.0.1'].includes(hostname)) {
  API_ROOT = 'http://localhost:3000';
} else {
  API_ROOT = VERCEL_API;
}

const API_BASE_URL = `${API_ROOT}/api/issues`;
const API_HEALTH_URL = `${API_ROOT}/api/health`;
