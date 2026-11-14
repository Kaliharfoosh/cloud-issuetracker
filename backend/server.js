// Runs the Express app on your PC: npm run dev  ->  http://localhost:3000
const app = require('./app');

const PORT = Number(process.env.PORT) || 3000;

app.listen(PORT, () => {
  const env = process.env.NODE_ENV || 'development';
  console.log(`Cloud Issue API listening on http://localhost:${PORT} (${env})`);
});

// Vercel (Lab 5) turns the exported Express app into one serverless function.
module.exports = app;
