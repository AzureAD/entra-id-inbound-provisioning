const express = require('express');
const { buildScimBulkPayloads } = require('../services/scimBuilder');
const { getAccessToken, sendBulkUpload } = require('../services/entraAuth');
const { parseEndpointIds } = require('../services/schemaUpdater');

const router = express.Router();

/**
 * POST /api/provisioning/preview
 * Generate SCIM bulk payload preview without sending.
 * Body: { mapping, customSchemaNamespace?, operationsPerRequest? }
 */
router.post('/preview', (req, res) => {
  try {
    const csvData = req.app.locals.csvData;
    if (!csvData) {
      return res.status(400).json({ error: 'No CSV data uploaded. Please upload a file first.' });
    }

    const { mapping, customSchemaNamespace, operationsPerRequest, customAttributeTypes } = req.body;
    if (!mapping) {
      return res.status(400).json({ error: 'Attribute mapping is required.' });
    }

    const payloads = buildScimBulkPayloads(
      csvData.rows,
      mapping,
      customSchemaNamespace || null,
      operationsPerRequest || 50,
      customAttributeTypes || null
    );

    res.json({
      totalPayloads: payloads.length,
      totalOperations: csvData.rows.length,
      payloads,
    });
  } catch (err) {
    console.error('Preview error:', err);
    res.status(500).json({ error: `Failed to generate payload: ${err.message}` });
  }
});

/**
 * POST /api/provisioning/send
 * Generate and send SCIM bulk payload to the Provisioning API.
 * Body: { mapping, config: { tenantId, clientId, clientSecret, endpoint }, customSchemaNamespace?, operationsPerRequest? }
 */
router.post('/send', async (req, res) => {
  try {
    const csvData = req.app.locals.csvData;
    if (!csvData) {
      return res.status(400).json({ error: 'No CSV data uploaded. Please upload a file first.' });
    }

    const { mapping, config, customSchemaNamespace, operationsPerRequest, customAttributeTypes } = req.body;
    if (!mapping) {
      return res.status(400).json({ error: 'Attribute mapping is required.' });
    }
    if (!config || !config.endpoint) {
      return res.status(400).json({ error: 'Connection configuration is incomplete. Provide at least an endpoint.' });
    }

    const authMethod = config.authMethod || 'certificate';
    if (authMethod === 'certificate' && (!config.tenantId || !config.clientId || !config.certificatePath)) {
      return res.status(400).json({ error: 'Certificate auth requires tenantId, clientId, and certificate file path.' });
    }
    if (authMethod === 'clientSecret' && (!config.tenantId || !config.clientId || !config.clientSecret)) {
      return res.status(400).json({ error: 'Client secret auth requires tenantId, clientId, and clientSecret.' });
    }

    // Build payloads
    const payloads = buildScimBulkPayloads(
      csvData.rows,
      mapping,
      customSchemaNamespace || null,
      operationsPerRequest || 50,
      customAttributeTypes || null
    );

    // Get access token
    let accessToken;
    try {
      accessToken = await getAccessToken(config.tenantId, config.clientId, config.clientSecret, {
        authMethod: config.authMethod || 'certificate',
        certificatePath: config.certificatePath,
        certificatePassword: config.certificatePassword,
        sendCertificateChain: config.sendCertificateChain,
        managedIdentityClientId: config.managedIdentityClientId,
      });
    } catch (authErr) {
      return res.status(401).json({
        error: `Authentication failed: ${authErr.message}`,
        details: 'Verify your Tenant ID, Client ID, and Client Secret. Ensure the app registration has the SynchronizationData-User.Upload permission.',
      });
    }

    // Send each payload batch
    const results = [];
    for (let i = 0; i < payloads.length; i++) {
      try {
        const result = await sendBulkUpload(config.endpoint, accessToken, payloads[i]);
        results.push({
          batch: i + 1,
          operationsCount: payloads[i].Operations.length,
          status: result.status,
          statusText: result.statusText,
          response: result.body,
        });
      } catch (sendErr) {
        results.push({
          batch: i + 1,
          operationsCount: payloads[i].Operations.length,
          status: 'error',
          error: sendErr.message,
        });
      }
    }

    res.json({
      totalBatches: payloads.length,
      totalOperations: csvData.rows.length,
      results,
    });
  } catch (err) {
    console.error('Send error:', err);
    res.status(500).json({ error: `Failed to send: ${err.message}` });
  }
});

/**
 * POST /api/provisioning/logs
 * Fetch recent provisioning logs from Microsoft Graph audit logs.
 * Body: { config: { tenantId, clientId, endpoint, authMethod, ... } }
 */
router.post('/logs', async (req, res) => {
  try {
    const { config } = req.body;
    if (!config?.endpoint) {
      return res.status(400).json({ error: 'Provisioning API endpoint is required.' });
    }

    let accessToken;
    try {
      accessToken = await getAccessToken(config.tenantId, config.clientId, config.clientSecret, {
        authMethod: config.authMethod || 'certificate',
        certificatePath: config.certificatePath,
        certificatePassword: config.certificatePassword,
        sendCertificateChain: config.sendCertificateChain,
        managedIdentityClientId: config.managedIdentityClientId,
      });
    } catch (authErr) {
      return res.status(401).json({
        error: `Authentication failed: ${authErr.message}`,
        details: 'Ensure your app registration has AuditLog.Read.All permission for reading provisioning logs.',
      });
    }

    // Parse service principal ID from endpoint
    const { servicePrincipalId } = parseEndpointIds(config.endpoint);

    // Query provisioning logs from the last 30 minutes filtered by this service principal
    const sinceTime = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const filter = encodeURIComponent(
      `activityDateTime ge ${sinceTime} and servicePrincipal/id eq '${servicePrincipalId}'`
    );
    const url = `https://graph.microsoft.com/beta/auditLogs/provisioning?$filter=${filter}&$top=100&$orderby=activityDateTime desc`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Failed to fetch provisioning logs (${response.status}): ${body}`);
    }

    const data = await response.json();
    const logs = (data.value || []).map(entry => ({
      id: entry.id,
      activityDateTime: entry.activityDateTime,
      action: entry.provisioningAction,
      status: entry.provisioningStatusInfo?.status || 'unknown',
      errorDescription: entry.provisioningStatusInfo?.errorInformation?.errorDetail || null,
      errorCode: entry.provisioningStatusInfo?.errorInformation?.errorCode || null,
      sourceIdentity: entry.sourceIdentity?.displayName || entry.sourceIdentity?.id || null,
      targetIdentity: entry.targetIdentity?.displayName || entry.targetIdentity?.id || null,
      initiatedBy: entry.initiatedBy?.displayName || 'System',
      jobId: entry.provisioningJobId || null,
    }));

    // Summarize
    const summary = {
      total: logs.length,
      success: logs.filter(l => l.status === 'success').length,
      failure: logs.filter(l => l.status === 'failure').length,
      skipped: logs.filter(l => l.status === 'skipped').length,
      warning: logs.filter(l => l.status === 'warning').length,
      other: logs.filter(l => !['success', 'failure', 'skipped', 'warning'].includes(l.status)).length,
    };

    res.json({ summary, logs });
  } catch (err) {
    console.error('Provisioning logs error:', err);
    res.status(500).json({ error: `Failed to fetch provisioning logs: ${err.message}` });
  }
});

module.exports = router;
