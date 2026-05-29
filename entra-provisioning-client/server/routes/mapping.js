const express = require('express');
const { SCIM_ATTRIBUTES } = require('../schemas/scimSchemas');

const router = express.Router();

/**
 * GET /api/mapping/schema
 * Return the available SCIM attributes for building the mapping UI.
 */
router.get('/schema', (req, res) => {
  res.json(SCIM_ATTRIBUTES);
});

/**
 * POST /api/mapping/validate
 * Validate an attribute mapping against uploaded CSV headers.
 * Body: { mapping: { scimPath: csvColumn, ... } }
 */
router.post('/validate', (req, res) => {
  const { mapping } = req.body;
  const csvData = req.app.locals.csvData;

  if (!mapping || typeof mapping !== 'object') {
    return res.status(400).json({ error: 'Invalid mapping object' });
  }

  const errors = [];
  const warnings = [];

  // Check required fields
  if (!mapping['externalId']) {
    errors.push('externalId is required — it uniquely identifies each user in the source system.');
  }
  if (!mapping['userName']) {
    warnings.push('userName is recommended — it is used as the login identifier.');
  }

  // Validate CSV column references
  if (csvData) {
    for (const [scimAttr, csvCol] of Object.entries(mapping)) {
      if (csvCol && !csvData.headers.includes(csvCol)) {
        errors.push(`CSV column "${csvCol}" (mapped to ${scimAttr}) does not exist in uploaded file.`);
      }
    }
  }

  res.json({
    valid: errors.length === 0,
    errors,
    warnings,
  });
});

module.exports = router;
