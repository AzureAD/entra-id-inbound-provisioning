import React, { useState } from 'react';

export default function ConnectionConfig({ config, setConfig }) {
  const [showSecret, setShowSecret] = useState(false);

  const update = (field, value) => {
    setConfig({ ...config, [field]: value });
  };

  const authMethod = config.authMethod || 'certificate';

  return (
    <div className="card">
      <h2>Connection Configuration</h2>
      <p className="subtitle">Enter your Entra ID app registration details and the provisioning API endpoint.</p>

      <div className="alert alert-success" style={{ marginBottom: 12 }}>
        <span>🔒</span>
        <div>
          <strong>Your credentials are safe.</strong> This app runs entirely on your local machine.
          Secrets are never stored on disk or sent anywhere except directly to Microsoft Entra ID when you click Send.
        </div>
      </div>

      {/* Provisioning Target */}
      <div className="form-group">
        <label>Provisioning Target</label>
        <div className="hint">Choose where users will be provisioned</div>
        <div className="target-selector">
          <label className={`target-option ${(config.provisioningTarget || 'entraId') === 'entraId' ? 'selected' : ''}`}>
            <input
              type="radio"
              name="provisioningTarget"
              value="entraId"
              checked={(config.provisioningTarget || 'entraId') === 'entraId'}
              onChange={e => update('provisioningTarget', e.target.value)}
            />
            <div>
              <strong>Microsoft Entra ID</strong>
              <span>Provision users to cloud-based Entra ID (Azure AD)</span>
            </div>
          </label>
          <label className={`target-option ${config.provisioningTarget === 'activeDirectory' ? 'selected' : ''}`}>
            <input
              type="radio"
              name="provisioningTarget"
              value="activeDirectory"
              checked={config.provisioningTarget === 'activeDirectory'}
              onChange={e => update('provisioningTarget', e.target.value)}
            />
            <div>
              <strong>On-premises Active Directory</strong>
              <span>Provision users to on-prem AD via Entra cloud sync provisioning agent</span>
            </div>
          </label>
        </div>
      </div>

      {/* Authentication Method */}
      <div className="form-group">
        <label>Authentication Method</label>
        <div className="hint">Choose how this app authenticates with Microsoft Entra ID</div>
        <div className="target-selector">
          <label className={`target-option ${authMethod === 'certificate' ? 'selected' : ''}`}>
            <input
              type="radio"
              name="authMethod"
              value="certificate"
              checked={authMethod === 'certificate'}
              onChange={e => update('authMethod', e.target.value)}
            />
            <div>
              <strong>Certificate</strong>
              <span>Authenticate with a certificate (.pem or .pfx) — more secure, no secret expiry</span>
            </div>
          </label>
          <label className={`target-option ${authMethod === 'clientSecret' ? 'selected' : ''}`}>
            <input
              type="radio"
              name="authMethod"
              value="clientSecret"
              checked={authMethod === 'clientSecret'}
              onChange={e => update('authMethod', e.target.value)}
            />
            <div>
              <strong>Client Secret <span style={{ fontWeight: 400, color: 'var(--text-secondary)' }}>(Not recommended)</span></strong>
              <span>Authenticate with a client secret from app registration</span>
            </div>
          </label>
        </div>
      </div>

      <div className="alert alert-info">
        <span>ℹ️</span>
        <div>
          <strong>Where to find these values:</strong>
          <ul style={{ marginTop: 4, paddingLeft: 20, fontSize: 13 }}>
            <li><strong>Tenant ID</strong> — Entra admin center → Overview → Tenant ID</li>
            <li><strong>Client ID</strong> — App registrations → Your app → Overview</li>
            {authMethod === 'certificate' && (
              <li><strong>Certificate</strong> — Upload .pem/.pfx to App registrations → Certificates & secrets → Certificates. Provide the local file path to the private key.</li>
            )}
            {authMethod === 'clientSecret' && (
              <li><strong>Client Secret</strong> — App registrations → Your app → Certificates & secrets → Client secrets</li>
            )}
            <li><strong>API Endpoint</strong> — Enterprise apps → Your provisioning app → Provisioning → Overview → Provisioning API Endpoint</li>
            {config.provisioningTarget === 'activeDirectory' && (
              <li><strong>Note:</strong> For on-prem AD, ensure Entra Cloud Sync provisioning agent is installed and configured</li>
            )}
          </ul>
        </div>
      </div>

      <div className="form-group">
        <label>Tenant ID</label>
        <div className="hint">Your Microsoft Entra ID (Azure AD) tenant identifier</div>
        <input
          type="text"
          placeholder="e.g. 00000000-0000-0000-0000-000000000000"
          value={config.tenantId || ''}
          onChange={e => update('tenantId', e.target.value)}
        />
      </div>

      <div className="form-group">
        <label>Client ID (Application ID)</label>
        <div className="hint">The application (client) ID of your app registration</div>
        <input
          type="text"
          placeholder="e.g. 00000000-0000-0000-0000-000000000000"
          value={config.clientId || ''}
          onChange={e => update('clientId', e.target.value)}
        />
      </div>

      {/* Certificate fields */}
      {authMethod === 'certificate' && (
        <>
          <div className="form-group">
            <label>Certificate File Path</label>
            <div className="hint">Absolute path to the .pem or .pfx certificate file on this server (e.g. /certs/app.pem or C:\certs\app.pfx)</div>
            <input
              type="text"
              placeholder="e.g. /home/user/certs/app-cert.pem"
              value={config.certificatePath || ''}
              onChange={e => update('certificatePath', e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Certificate Password <span style={{ fontWeight: 400, color: 'var(--text-secondary)' }}>(optional)</span></label>
            <div className="hint">If the certificate is password-protected (.pfx), enter the password</div>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                type={showSecret ? 'text' : 'password'}
                placeholder="Certificate password (if any)"
                value={config.certificatePassword || ''}
                onChange={e => update('certificatePassword', e.target.value)}
                style={{ flex: 1 }}
              />
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setShowSecret(!showSecret)}
                style={{ whiteSpace: 'nowrap' }}
              >
                {showSecret ? 'Hide' : 'Show'}
              </button>
            </div>
          </div>
          <div className="form-group">
            <label className="custom-attrs-toggle" style={{ fontWeight: 600 }}>
              <input
                type="checkbox"
                checked={config.sendCertificateChain || false}
                onChange={e => update('sendCertificateChain', e.target.checked)}
              />
              Send certificate chain (x5c header)
            </label>
            <div className="hint">Enable if your Entra app is configured for Subject Name/Issuer (SNI) authentication</div>
          </div>
        </>
      )}

      {/* Client Secret fields */}
      {authMethod === 'clientSecret' && (
        <div className="form-group">
          <label>Client Secret</label>
          <div className="hint">A client secret from your app registration</div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input
              type={showSecret ? 'text' : 'password'}
              placeholder="Enter client secret"
              value={config.clientSecret || ''}
              onChange={e => update('clientSecret', e.target.value)}
              style={{ flex: 1 }}
            />
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setShowSecret(!showSecret)}
              style={{ whiteSpace: 'nowrap' }}
            >
              {showSecret ? 'Hide' : 'Show'}
            </button>
          </div>
        </div>
      )}

      <div className="form-group">
        <label>Provisioning API Endpoint</label>
        <div className="hint">
          {config.provisioningTarget === 'activeDirectory'
            ? 'The bulkUpload API endpoint URL from your API-driven provisioning to on-premises AD app'
            : 'The bulkUpload API endpoint URL from your provisioning app'}
        </div>
        <input
          type="url"
          placeholder="https://graph.microsoft.com/beta/servicePrincipals/{id}/synchronization/jobs/{jobId}/bulkUpload"
          value={config.endpoint || ''}
          onChange={e => update('endpoint', e.target.value)}
        />
      </div>

      {config.provisioningTarget === 'activeDirectory' && (
        <div className="alert alert-warning" style={{ marginTop: 0 }}>
          <span>⚠️</span>
          <div>
            <strong>On-premises AD provisioning requires:</strong>
            <ul style={{ marginTop: 4, paddingLeft: 20, fontSize: 13 }}>
              <li>Microsoft Entra Cloud Sync provisioning agent installed on a domain-joined server</li>
              <li>API-driven provisioning to AD app configured in Entra admin center</li>
              <li>The provisioning agent must be running and connected</li>
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}
