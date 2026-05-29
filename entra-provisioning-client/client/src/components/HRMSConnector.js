import React, { useEffect, useState } from 'react';
import { getConnectors, testHRMSConnection, fetchHRMSData } from '../services/api';

export default function HRMSConnector({ onDataLoaded }) {
  const [connectors, setConnectors] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [connectorConfig, setConnectorConfig] = useState({});
  const [showSecrets, setShowSecrets] = useState({});
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState(null);
  const [fetching, setFetching] = useState(false);
  const [fetchResult, setFetchResult] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    getConnectors().then(setConnectors).catch(err => setError(err.message));
  }, []);

  const selected = connectors.find(c => c.id === selectedId);

  const updateConfig = (key, value) => {
    setConnectorConfig(prev => ({ ...prev, [key]: value }));
  };

  const toggleSecret = (key) => {
    setShowSecrets(prev => ({ ...prev, [key]: !prev[key] }));
  };

  const handleSelectConnector = (id) => {
    setSelectedId(id);
    setConnectorConfig({});
    setTestResult(null);
    setFetchResult(null);
    setError(null);
    // Pre-fill authType from connector
    const connector = connectors.find(c => c.id === id);
    if (connector) {
      const defaults = {};
      connector.configFields.forEach(f => {
        if (f.default) defaults[f.key] = f.default;
      });
      defaults.authType = connector.authType;
      setConnectorConfig(defaults);
    }
  };

  const handleTest = async () => {
    setTesting(true);
    setTestResult(null);
    setError(null);
    try {
      const result = await testHRMSConnection(selectedId, connectorConfig);
      setTestResult(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setTesting(false);
    }
  };

  const handleFetch = async () => {
    setFetching(true);
    setFetchResult(null);
    setError(null);
    try {
      const result = await fetchHRMSData(selectedId, connectorConfig);
      setFetchResult(result);
      onDataLoaded(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setFetching(false);
    }
  };

  const isConfigValid = () => {
    if (!selected) return false;
    return selected.configFields
      .filter(f => f.required)
      .every(f => connectorConfig[f.key]?.trim());
  };

  return (
    <div className="card">
      <h2>HRMS Integration</h2>
      <p className="subtitle">Select your HR system and configure the API connection to pull employee data.</p>

      {/* Connector Grid */}
      {!selectedId && (
        <div className="connector-grid">
          {connectors.map(c => (
            <div
              key={c.id}
              className="connector-card"
              onClick={() => handleSelectConnector(c.id)}
            >
              <div className="connector-icon">{c.icon}</div>
              <div className="connector-info">
                <strong>{c.name}</strong>
                <span className="connector-category">{c.category}</span>
                <p>{c.description}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Selected Connector Config */}
      {selected && (
        <>
          <div className="connector-header">
            <button className="btn btn-secondary" onClick={() => { setSelectedId(null); setTestResult(null); setFetchResult(null); }}>
              ← Back to connectors
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ fontSize: 28 }}>{selected.icon}</span>
              <div>
                <strong style={{ fontSize: 16 }}>{selected.name}</strong>
                <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{selected.category} · {selected.authType} auth</div>
              </div>
            </div>
          </div>

          <div className="alert alert-info" style={{ marginTop: 16 }}>
            <span>ℹ️</span>
            <div>
              Configure the API connection below. Required fields are marked with <span style={{ color: 'var(--danger)' }}>*</span>.
              {selected.id === 'customApi' && (
                <span> Use the Custom REST API connector to connect to any system that returns JSON data.</span>
              )}
            </div>
          </div>

          {/* Config Form */}
          {selected.configFields.map(field => (
            <div className="form-group" key={field.key}>
              <label>
                {field.label}
                {field.required && <span style={{ color: 'var(--danger)', marginLeft: 4 }}>*</span>}
              </label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  type={field.secret && !showSecrets[field.key] ? 'password' : 'text'}
                  placeholder={field.placeholder}
                  value={connectorConfig[field.key] || ''}
                  onChange={e => updateConfig(field.key, e.target.value)}
                  style={{ flex: 1 }}
                />
                {field.secret && (
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => toggleSecret(field.key)}
                    style={{ whiteSpace: 'nowrap' }}
                  >
                    {showSecrets[field.key] ? 'Hide' : 'Show'}
                  </button>
                )}
              </div>
            </div>
          ))}

          {/* Action Buttons */}
          <div className="btn-group" style={{ marginTop: 20 }}>
            <button
              className="btn btn-secondary"
              onClick={handleTest}
              disabled={!isConfigValid() || testing}
            >
              {testing ? <><span className="spinner" /> Testing...</> : '🔍 Test Connection'}
            </button>
            <button
              className="btn btn-primary"
              onClick={handleFetch}
              disabled={!isConfigValid() || fetching}
            >
              {fetching ? <><span className="spinner" /> Fetching...</> : '⬇️ Fetch Employee Data'}
            </button>
          </div>

          {/* Test Result */}
          {testResult && (
            <div className={`alert ${testResult.success ? 'alert-success' : 'alert-error'}`} style={{ marginTop: 16 }}>
              {testResult.success ? '✅' : '❌'} {testResult.message}
              {testResult.success && testResult.sampleHeaders && (
                <div style={{ marginTop: 8, fontSize: 12 }}>
                  <strong>Discovered fields:</strong> {testResult.sampleHeaders.join(', ')}
                  {testResult.sampleHeaders.length >= 20 && '...'}
                </div>
              )}
            </div>
          )}

          {/* Fetch Result */}
          {fetchResult && (
            <>
              <div className="alert alert-success" style={{ marginTop: 16 }}>
                ✅ <strong>{fetchResult.source}</strong> — {fetchResult.totalRows} records, {fetchResult.headers.length} fields
              </div>

              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      {fetchResult.headers.slice(0, 10).map(h => <th key={h}>{h}</th>)}
                      {fetchResult.headers.length > 10 && <th>+{fetchResult.headers.length - 10} more</th>}
                    </tr>
                  </thead>
                  <tbody>
                    {fetchResult.preview.map((row, i) => (
                      <tr key={i}>
                        {fetchResult.headers.slice(0, 10).map(h => <td key={h} title={row[h]}>{row[h]}</td>)}
                        {fetchResult.headers.length > 10 && <td>...</td>}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 8 }}>
                Showing first {fetchResult.preview.length} of {fetchResult.totalRows} records · {fetchResult.headers.length} fields discovered
              </p>
            </>
          )}

          {error && <div className="alert alert-error" style={{ marginTop: 16 }}>❌ {error}</div>}
        </>
      )}
    </div>
  );
}
