require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const uploadRoutes = require('./routes/upload');
const mappingRoutes = require('./routes/mapping');
const provisioningRoutes = require('./routes/provisioning');
const connectorRoutes = require('./routes/connectors');
const schemaRoutes = require('./routes/schema');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// API Routes
app.use('/api/upload', uploadRoutes);
app.use('/api/mapping', mappingRoutes);
app.use('/api/provisioning', provisioningRoutes);
app.use('/api/connectors', connectorRoutes);
app.use('/api/schema', schemaRoutes);

// Serve React frontend in production
const clientBuildPath = path.join(__dirname, '..', 'client', 'build');
app.use(express.static(clientBuildPath));
app.get('*', (req, res) => {
  res.sendFile(path.join(clientBuildPath, 'index.html'));
});

const HOST = process.env.HOST || '127.0.0.1';

app.listen(PORT, HOST, () => {
  console.log(`\n  Entra Provisioning Client running at http://${HOST}:${PORT}`);
  console.log(`  All credentials stay on this machine — nothing leaves until you click Send.\n`);
});
