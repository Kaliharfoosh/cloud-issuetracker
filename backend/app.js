// The Express app: middleware + routes (the same app as Labs 4 and 5).
// It does NOT start a server. Two files use it:
//   server.js  -> runs it on your PC (npm run dev)
//   lambda.js  -> runs it on AWS Lambda
require('dotenv').config({ quiet: true });

const express = require('express');
const cors = require('cors');
const issueRoutes = require('./routes/issues');

const app = express();

// Log every request
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.originalUrl}`);
  next();
});

// Lab 5: allowed frontend origins come from .env (comma-separated)
const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:8080')
  .split(',')
  .map((origin) => origin.trim());

app.use(cors({
  origin: allowedOrigins
}));

// Parse JSON bodies
app.use(express.json());

// Lab 7: some API Gateway emulators hand Lambda the body as raw bytes or base64 text
// (for example for PATCH). serverless-http then leaves it as a Buffer/string that
// express.json() skipped, and req.body.status is undefined. Turn it into an object here.
app.use((req, res, next) => {
  if (Buffer.isBuffer(req.body) || typeof req.body === 'string') {
    const text = req.body.toString('utf8').trim();
    const decoded = /^[A-Za-z0-9+/=\s]+$/.test(text) && !text.startsWith('{')
      ? Buffer.from(text, 'base64').toString('utf8')
      : text;
    try {
      req.body = decoded ? JSON.parse(decoded) : {};
    } catch {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: 'Request body is not valid JSON.' }
      });
    }
  }
  if (req.body === undefined || req.body === null) req.body = {};
  next();
});

// Friendly root route: opening the API's Vercel URL in a browser shows where to go
app.get('/', (req, res) => {
  res.status(200).json({
    name: 'Cloud Issue Tracker API',
    endpoints: ['/api/health', '/api/issues']
  });
});

// Health check: proves the deployment is running without touching the database.
// Lab 7: AWS sets AWS_LAMBDA_FUNCTION_NAME inside every Lambda function,
// so runtime is "lambda" in the cloud and "pc" on your laptop.
app.get('/api/health', (req, res) => {
  const runtime = process.env.AWS_LAMBDA_FUNCTION_NAME ? 'lambda' : 'pc';
  res.status(200).json({ status: 'ok',
    environment: process.env.NODE_ENV || 'development', runtime });
});

// Issue routes (GET, POST, PATCH)
app.use('/api/issues', issueRoutes);

// Route not found
app.use((req, res) => {
  res.status(404).json({
    error: { code: 'ROUTE_NOT_FOUND', message: 'Route not found.' }
  });
});

// Central error handler
app.use((error, req, res, next) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: 'Request body is not valid JSON.' }
    });
  }
  console.error(error);
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'An unexpected server error occurred.' }
  });
});

module.exports = app;
