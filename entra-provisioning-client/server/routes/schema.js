const express = require('express');
const { getAccessToken } = require('../services/entraAuth');
const { ensureCustomSchemaAttributes } = require('../services/schemaUpdater');
const { validateGraphEndpoint } = require('../services/validateGraphEndpoint');

const router = express.Router();

/**
 * POST /api/schema/update
 * Ensure custom attributes AND standard attribute mappings exist in the
 * provisioning job schema. Automatically reads, patches, and updates
 * the schema via Graph API.
 *
 * Body: { config, customAttributes, mapping }
 */
router.post('/update', async (req, res) => {
  try {
    const { config, customAttributes, mapping } = req.body;

    if (!config?.endpoint) {
      return res.status(400).json({ error: 'Provisioning API endpoint is required.' });
    }

    // Validate the client-supplied endpoint before attaching a Graph token to it.
    const endpointCheck = validateGraphEndpoint(config.endpoint);
    if (!endpointCheck.valid) {
      return res.status(400).json({ error: endpointCheck.error });
    }

    const hasCustom = customAttributes?.enabled && customAttributes?.namespace && customAttributes?.attributes?.length;
    const hasMapping = mapping && Object.keys(mapping).length > 0;

    if (!hasCustom && !hasMapping) {
      return res.json({
        updated: false,
        attributesAdded: [],
        mappingsAdded: [],
        message: 'No attributes or mappings to sync to the schema.',
      });
    }

    // Get access token (needs Synchronization.ReadWrite.All permission)
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
        details: 'Ensure your app registration has Synchronization.ReadWrite.All permission for schema updates.',
      });
    }

    const result = await ensureCustomSchemaAttributes(accessToken, config.endpoint, customAttributes, mapping);
    res.json(result);
  } catch (err) {
    console.error('Schema update error:', err);
    res.status(500).json({ error: `Schema update failed: ${err.message}` });
  }
});

module.exports = router;
