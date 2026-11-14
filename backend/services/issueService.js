// Chooses where issues are stored. The controller always imports THIS file,
// so routes and controller never change when the storage changes.
//
//   DYNAMODB_TABLE set  -> Amazon DynamoDB             (Lab 7: Lambda, or your PC with Floci)
//   DATABASE_URL set    -> Neon Postgres               (Lab 5: required on Vercel)
//   both empty          -> backend/data/issues.json    (Lab 4: your PC only)
const dynamoTable = (process.env.DYNAMODB_TABLE || '').trim();
const databaseUrl = (process.env.DATABASE_URL || '').trim();
const inTheCloud = Boolean(process.env.VERCEL) || process.env.NODE_ENV === 'production';

function missingDatabase() {
  // Vercel's file system is temporary, so the JSON file cannot be used there.
  // Answering 500 (while /api/health still works) points straight at the missing setting.
  throw new Error('DATABASE_URL is not set. Add it in Vercel: Settings > Environment Variables, then Redeploy.');
}

let service;
if (dynamoTable) {
  service = require('./dynamoIssueService');
  console.log(`Issue storage: DynamoDB table ${dynamoTable}`);
} else if (databaseUrl) {
  service = require('./neonIssueService');
  console.log('Issue storage: Neon Postgres (DATABASE_URL)');
} else if (inTheCloud) {
  service = { readIssues: missingDatabase, createIssue: missingDatabase, updateIssueStatus: missingDatabase };
  console.error('Issue storage: NOT CONFIGURED. DATABASE_URL is missing.');
} else {
  service = require('./jsonIssueService');
  console.log('Issue storage: local JSON file (backend/data/issues.json)');
}

module.exports = service;
