const {
  ClientSecretCredential,
  ClientCertificateCredential,
} = require('@azure/identity');
const fs = require('fs');
const path = require('path');

/**
 * Acquire a bearer token for the Entra ID Provisioning API.
 * Supports two auth methods: certificate (primary), clientSecret (secondary).
 */
async function getAccessToken(tenantId, clientId, clientSecret, authConfig) {
  const authMethod = authConfig?.authMethod || 'certificate';
  let credential;

  switch (authMethod) {
    case 'certificate': {
      const certPath = authConfig.certificatePath;
      if (!certPath) {
        throw new Error('Certificate file path is required for certificate-based authentication.');
      }
      const resolvedPath = path.resolve(certPath);
      if (!fs.existsSync(resolvedPath)) {
        throw new Error(`Certificate file not found: ${resolvedPath}`);
      }
      const opts = {};
      if (authConfig.certificatePassword) {
        opts.certificatePassword = authConfig.certificatePassword;
      }
      if (authConfig.sendCertificateChain) {
        opts.sendCertificateChain = true;
      }
      credential = new ClientCertificateCredential(tenantId, clientId, {
        certificatePath: resolvedPath,
        ...opts,
      });
      break;
    }
    case 'clientSecret': {
      if (!clientSecret) {
        throw new Error('Client secret is required for client secret authentication.');
      }
      credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
      break;
    }
    default: {
      throw new Error(`Unsupported auth method: ${authMethod}. Use 'certificate' or 'clientSecret'.`);
    }
  }

  const tokenResponse = await credential.getToken('https://graph.microsoft.com/.default');
  return tokenResponse.token;
}

/**
 * Send a SCIM bulk request payload to the Provisioning API endpoint.
 * @param {string} endpoint - The bulkUpload API endpoint URL
 * @param {string} accessToken - Bearer token
 * @param {Object} payload - SCIM BulkRequest payload
 * @returns {Object} { status, statusText, body }
 */
async function sendBulkUpload(endpoint, accessToken, payload) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/scim+json',
    },
    body: JSON.stringify(payload),
  });

  let body;
  const contentType = response.headers.get('content-type');
  if (contentType && contentType.includes('json')) {
    body = await response.json();
  } else {
    body = await response.text();
  }

  return {
    status: response.status,
    statusText: response.statusText,
    body,
  };
}

module.exports = { getAccessToken, sendBulkUpload };
