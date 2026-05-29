import React, { useState, useEffect, useRef } from 'react';
import { sendToApi, updateProvisioningSchema, getProvisioningLogs } from '../services/api';

export default function SubmitResult({ mapping, config, customAttributes }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [results, setResults] = useState(null);
  const [schemaStatus, setSchemaStatus] = useState(null); // { updating, result, error }
  const [logStatus, setLogStatus] = useState(null); // { polling, logs, summary, error }
  const pollRef = useRef(null);

  // Cleanup polling on unmount
  useEffect(() => {
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, []);

  const handleSend = async () => {
    const method = config.authMethod || 'certificate';
    if (!config.endpoint) {
      setError('Please provide the provisioning API endpoint in Step 1.');
      return;
    }
    if (method === 'certificate' && (!config.tenantId || !config.clientId || !config.certificatePath)) {
      setError('Please complete the certificate configuration in Step 1 before sending.');
      return;
    }
    if (method === 'clientSecret' && (!config.tenantId || !config.clientId || !config.clientSecret)) {
      setError('Please complete the client secret configuration in Step 1 before sending.');
      return;
    }

    setLoading(true);
    setError(null);
    setResults(null);
    setSchemaStatus(null);
    setLogStatus(null);
    if (pollRef.current) clearInterval(pollRef.current);

    // Step 1: Auto-update provisioning app schema & attribute mappings
    const hasCustom = customAttributes?.enabled && customAttributes?.attributes?.length > 0;
    const hasMappings = mapping && Object.keys(mapping).length > 0;

    if (hasCustom || hasMappings) {
      setSchemaStatus({ updating: true, result: null, error: null });
      try {
        const schemaResult = await updateProvisioningSchema(config, customAttributes, mapping);
        setSchemaStatus({ updating: false, result: schemaResult, error: null });
      } catch (schemaErr) {
        setSchemaStatus({ updating: false, result: null, error: schemaErr.message });
        // Don't block sending — schema update is best-effort
      }
    }

    // Step 2: Send the provisioning payload
    try {
      const data = await sendToApi(mapping, config, customAttributes);
      setResults(data);
      // Step 3: Start polling provisioning logs
      startLogPolling();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const startLogPolling = () => {
    setLogStatus({ polling: true, logs: [], summary: null, error: null });
    let attempts = 0;
    const maxAttempts = 12; // Poll for up to ~2 minutes

    const poll = async () => {
      attempts++;
      try {
        const data = await getProvisioningLogs(config);
        setLogStatus(prev => ({
          ...prev,
          logs: data.logs,
          summary: data.summary,
          error: null,
          polling: attempts < maxAttempts && data.summary?.total === 0,
        }));
        // Stop polling once we have logs or max attempts
        if (data.summary?.total > 0 || attempts >= maxAttempts) {
          clearInterval(pollRef.current);
          pollRef.current = null;
          setLogStatus(prev => ({ ...prev, polling: false }));
        }
      } catch (logErr) {
        if (attempts >= maxAttempts) {
          clearInterval(pollRef.current);
          pollRef.current = null;
          setLogStatus(prev => ({
            ...prev,
            polling: false,
            error: logErr.message,
          }));
        }
      }
    };

    // Initial delay before first poll (give Entra time to process)
    setTimeout(() => {
      poll();
      pollRef.current = setInterval(poll, 10000); // Poll every 10s
    }, 5000);
  };

  const handleRefreshLogs = async () => {
    setLogStatus(prev => ({ ...prev, polling: true, error: null }));
    try {
      const data = await getProvisioningLogs(config);
      setLogStatus({ polling: false, logs: data.logs, summary: data.summary, error: null });
    } catch (err) {
      setLogStatus(prev => ({ ...prev, polling: false, error: err.message }));
    }
  };

  const allSuccess = results?.results?.every(r => r.status >= 200 && r.status < 300);

  return (
    <div className="card">
      <h2>Send to Entra ID</h2>
      <p className="subtitle">Submit the SCIM bulk request to the Provisioning API endpoint.</p>

      <div className="alert alert-warning">
        <span>⚠️</span>
        <div>
          <strong>Before sending, ensure:</strong>
          <ul style={{ marginTop: 4, paddingLeft: 20, fontSize: 13 }}>
            <li>The provisioning app is configured and started in Entra admin center</li>
            <li>Your app registration has <code>SynchronizationData-User.Upload</code> permission</li>
            <li>For syncing attribute mappings to the provisioning app, <code>Synchronization.ReadWrite.All</code> permission is also needed</li>
            <li>For provisioning log monitoring, <code>AuditLog.Read.All</code> permission is recommended</li>
            <li>You have reviewed the payload preview in the previous step</li>
          </ul>
        </div>
      </div>

      <div className="btn-group" style={{ marginTop: 0 }}>
        <button className="btn btn-success" onClick={handleSend} disabled={loading}>
          {loading ? <><span className="spinner" /> Sending...</> : '🚀 Send to Provisioning API'}
        </button>
      </div>

      {error && <div className="alert alert-error" style={{ marginTop: 16 }}>❌ {error}</div>}

      {/* Schema Update Status */}
      {schemaStatus && (
        <div style={{ marginTop: 16 }}>
          <h3 style={{ fontSize: 15, marginBottom: 8 }}>Schema Update</h3>
          {schemaStatus.updating && (
            <div className="alert alert-info"><span className="spinner" /> Syncing attribute mappings to provisioning app schema...</div>
          )}
          {schemaStatus.result && (
            <div className={`alert ${schemaStatus.result.updated ? 'alert-success' : 'alert-info'}`}>
              {schemaStatus.result.updated ? '✅' : 'ℹ️'} {schemaStatus.result.message}
              {schemaStatus.result.attributesAdded?.length > 0 && (
                <>
                  <div style={{ marginTop: 4, fontSize: 13, fontWeight: 600 }}>Source attributes added:</div>
                  <ul style={{ marginTop: 2, paddingLeft: 20, fontSize: 13 }}>
                    {schemaStatus.result.attributesAdded.map((a, i) => (
                      <li key={i}><code>{a}</code></li>
                    ))}
                  </ul>
                </>
              )}
              {schemaStatus.result.mappingsAdded?.length > 0 && (
                <>
                  <div style={{ marginTop: 4, fontSize: 13, fontWeight: 600 }}>Attribute mappings configured:</div>
                  <ul style={{ marginTop: 2, paddingLeft: 20, fontSize: 13 }}>
                    {schemaStatus.result.mappingsAdded.map((m, i) => (
                      <li key={i}><code>{m}</code></li>
                    ))}
                  </ul>
                </>
              )}
            </div>
          )}
          {schemaStatus.error && (
            <div className="alert alert-warning">
              ⚠️ Schema update failed (payload will still be sent): {schemaStatus.error}
            </div>
          )}
        </div>
      )}

      {/* Send Results */}
      {results && (
        <>
          <div className={`alert ${allSuccess ? 'alert-success' : 'alert-warning'}`} style={{ marginTop: 16 }}>
            {allSuccess ? '✅' : '⚠️'} Sent <strong>{results.totalBatches} batch(es)</strong> with
            <strong> {results.totalOperations} operations</strong>.
          </div>

          {results.results.map((r, i) => (
            <div key={i} className={`result-item ${r.status >= 200 && r.status < 300 ? 'success' : 'error'}`}>
              <span className={`status-badge ${r.status >= 200 && r.status < 300 ? 'success' : 'error'}`}>
                {r.status} {r.statusText || ''}
              </span>
              <span>Batch {r.batch} — {r.operationsCount} operations</span>
              {r.error && <span style={{ color: 'var(--danger)', fontSize: 13 }}>{r.error}</span>}
            </div>
          ))}

          {results.results.some(r => r.response) && (
            <details style={{ marginTop: 16 }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: 14 }}>View API Response Details</summary>
              <pre style={{
                background: 'var(--code-bg)', color: 'var(--code-text)', padding: 16,
                borderRadius: 8, marginTop: 8, fontSize: 12, overflow: 'auto', maxHeight: 400
              }}>
                {JSON.stringify(results.results, null, 2)}
              </pre>
            </details>
          )}
        </>
      )}

      {/* Provisioning Log Monitor */}
      {logStatus && (
        <div style={{ marginTop: 24 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
            <h3 style={{ fontSize: 15, margin: 0 }}>Provisioning Logs</h3>
            {!logStatus.polling && (
              <button className="btn btn-secondary" onClick={handleRefreshLogs} style={{ fontSize: 12, padding: '4px 12px' }}>
                ↻ Refresh
              </button>
            )}
          </div>

          {logStatus.polling && (
            <div className="alert alert-info">
              <span className="spinner" /> Monitoring provisioning logs... (checking every 10 seconds)
            </div>
          )}

          {logStatus.error && (
            <div className="alert alert-warning">
              ⚠️ Could not fetch provisioning logs: {logStatus.error}
              <div style={{ fontSize: 13, marginTop: 4 }}>
                Ensure your app has <code>AuditLog.Read.All</code> permission. You can also check logs in the Entra admin center.
              </div>
            </div>
          )}

          {logStatus.summary && logStatus.summary.total > 0 && (
            <>
              <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 12 }}>
                <div className="log-summary-badge" style={{ background: 'var(--success-bg)', color: 'var(--success)', padding: '6px 14px', borderRadius: 8, fontWeight: 600, fontSize: 14 }}>
                  ✅ {logStatus.summary.success} Successful
                </div>
                {logStatus.summary.failure > 0 && (
                  <div className="log-summary-badge" style={{ background: 'var(--danger-bg, #fce4e4)', color: 'var(--danger)', padding: '6px 14px', borderRadius: 8, fontWeight: 600, fontSize: 14 }}>
                    ❌ {logStatus.summary.failure} Failed
                  </div>
                )}
                {logStatus.summary.skipped > 0 && (
                  <div className="log-summary-badge" style={{ background: 'var(--warning-bg)', color: 'var(--warning)', padding: '6px 14px', borderRadius: 8, fontWeight: 600, fontSize: 14 }}>
                    ⏭️ {logStatus.summary.skipped} Skipped
                  </div>
                )}
                {logStatus.summary.warning > 0 && (
                  <div className="log-summary-badge" style={{ background: 'var(--warning-bg)', color: 'var(--warning)', padding: '6px 14px', borderRadius: 8, fontWeight: 600, fontSize: 14 }}>
                    ⚠️ {logStatus.summary.warning} Warnings
                  </div>
                )}
              </div>

              <div style={{ maxHeight: 400, overflow: 'auto', border: '1px solid var(--border)', borderRadius: 8 }}>
                <table className="data-table" style={{ width: '100%', fontSize: 13 }}>
                  <thead>
                    <tr>
                      <th>Status</th>
                      <th>Action</th>
                      <th>Source</th>
                      <th>Target</th>
                      <th>Time</th>
                      <th>Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {logStatus.logs.map((log, i) => (
                      <tr key={log.id || i}>
                        <td>
                          <span className={`status-badge ${log.status === 'success' ? 'success' : log.status === 'failure' ? 'error' : 'warning'}`}>
                            {log.status}
                          </span>
                        </td>
                        <td>{log.action || '—'}</td>
                        <td>{log.sourceIdentity || '—'}</td>
                        <td>{log.targetIdentity || '—'}</td>
                        <td>{log.activityDateTime ? new Date(log.activityDateTime).toLocaleTimeString() : '—'}</td>
                        <td style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {log.errorDescription || '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}

          {logStatus.summary && logStatus.summary.total === 0 && !logStatus.polling && (
            <div className="alert alert-info">
              ℹ️ No provisioning logs found in the last 30 minutes. Logs may take a few minutes to appear.
              Click <strong>Refresh</strong> to check again.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
