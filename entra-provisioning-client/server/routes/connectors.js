const express = require('express');
const { listConnectors, getConnector } = require('../connectors/registry');
const { fetchHRMSData, testConnection } = require('../services/hrmsClient');

const router = express.Router();

/**
 * GET /api/connectors
 * List all available HRMS connectors.
 */
router.get('/', (req, res) => {
  res.json(listConnectors());
});

/**
 * GET /api/connectors/:id
 * Get a specific connector's configuration schema.
 */
router.get('/:id', (req, res) => {
  const connector = getConnector(req.params.id);
  if (!connector) {
    return res.status(404).json({ error: `Connector '${req.params.id}' not found` });
  }
  res.json({
    id: connector.id,
    name: connector.name,
    description: connector.description,
    icon: connector.icon,
    category: connector.category,
    authType: connector.authType,
    configFields: connector.configFields,
    sampleFieldHints: connector.sampleFieldHints,
  });
});

/**
 * POST /api/connectors/:id/test
 * Test connectivity to an HRMS with the provided configuration.
 */
router.post('/:id/test', async (req, res) => {
  const connector = getConnector(req.params.id);
  if (!connector) {
    return res.status(404).json({ error: `Connector '${req.params.id}' not found` });
  }

  try {
    const result = await testConnection(connector, req.body);
    res.json(result);
  } catch (err) {
    console.error('HRMS test error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * POST /api/connectors/:id/fetch
 * Fetch employee data from an HRMS and store it like CSV data.
 */
router.post('/:id/fetch', async (req, res) => {
  const connector = getConnector(req.params.id);
  if (!connector) {
    return res.status(404).json({ error: `Connector '${req.params.id}' not found` });
  }

  try {
    const maxRecords = req.body.maxRecords || 1000;
    const { headers, rows, totalFetched } = await fetchHRMSData(connector, req.body, maxRecords);

    // Store in app.locals just like CSV upload does
    req.app.locals.csvData = { headers, rows };

    res.json({
      source: connector.name,
      totalRows: totalFetched,
      headers,
      preview: rows.slice(0, 5),
      fieldHints: connector.sampleFieldHints || {},
    });
  } catch (err) {
    console.error('HRMS fetch error:', err);
    res.status(500).json({ error: `Failed to fetch from ${connector.name}: ${err.message}` });
  }
});

module.exports = router;
