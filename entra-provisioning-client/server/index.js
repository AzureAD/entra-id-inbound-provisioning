require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const uploadRoutes = require('./routes/upload');
const mappingRoutes = require('./routes/mapping');
const provisioningRoutes = require('./routes/provisioning');
const connectorRoutes = require('./routes/connectors');
const schemaRoutes = require('./routes/schema');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
// Restrict CORS: allow the CRA dev server origin in development; same-origin in production.
const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:3000,http://127.0.0.1:3000')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);
app.use(cors({
  origin(origin, callback) {
    // Allow non-browser requests (no Origin header) and whitelisted dev origins.
    if (!origin || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    // For any other origin, don't add CORS headers (callback(null, false)) rather than
    // throwing. Browsers send an Origin header even on same-origin non-GET requests (e.g.
    // the production app's own POST /api/upload), so throwing here would 500 those requests.
    // Returning false lets same-origin requests proceed normally while still preventing
    // disallowed cross-origin sites from reading responses.
    return callback(null, false);
  },
}));
app.use(express.json({ limit: '50mb' }));

// API Routes
app.use('/api/upload', uploadRoutes);
app.use('/api/mapping', mappingRoutes);
app.use('/api/provisioning', provisioningRoutes);
app.use('/api/connectors', connectorRoutes);
app.use('/api/schema', schemaRoutes);

// Serve React frontend in production. In development the client/build folder
// may not exist, so only enable static serving when it's present.
const clientBuildPath = path.join(__dirname, '..', 'client', 'build');
if (fs.existsSync(path.join(clientBuildPath, 'index.html'))) {
  app.use(express.static(clientBuildPath));
  app.get('*', (req, res) => {
    res.sendFile(path.join(clientBuildPath, 'index.html'));
  });
}

const HOST = process.env.HOST || '127.0.0.1';

app.listen(PORT, HOST, () => {
  console.log(`\n  Entra Provisioning Client running at http://${HOST}:${PORT}`);
  console.log(`  All credentials stay on this machine — nothing leaves until you click Send.\n`);
});
