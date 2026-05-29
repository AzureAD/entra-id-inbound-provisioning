import React, { useState } from 'react';
import { previewPayload } from '../services/api';

export default function PayloadPreview({ mapping, customAttributes }) {
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState(0);

  const handleGenerate = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await previewPayload(mapping, customAttributes);
      setPreview(data);
      setActiveTab(0);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDownload = () => {
    if (!preview) return;
    const blob = new Blob([JSON.stringify(preview.payloads, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `scim-bulk-request-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="card">
      <h2>SCIM Payload Preview</h2>
      <p className="subtitle">Generate and review the SCIM bulk request payload before sending to the API.</p>

      <div className="btn-group" style={{ marginTop: 0 }}>
        <button className="btn btn-primary" onClick={handleGenerate} disabled={loading}>
          {loading ? <><span className="spinner" /> Generating...</> : '🔄 Generate Preview'}
        </button>
        {preview && (
          <button className="btn btn-secondary" onClick={handleDownload}>
            📥 Download JSON
          </button>
        )}
      </div>

      {error && <div className="alert alert-error" style={{ marginTop: 16 }}>❌ {error}</div>}

      {preview && (
        <>
          <div className="alert alert-info" style={{ marginTop: 16 }}>
            ℹ️ Generated <strong>{preview.totalPayloads} batch(es)</strong> with <strong>{preview.totalOperations} total operations</strong>.
            {preview.totalPayloads > 1 && ' Each batch contains up to 50 operations.'}
          </div>

          {preview.totalPayloads > 1 && (
            <div style={{ display: 'flex', gap: 4, marginBottom: 12 }}>
              {preview.payloads.map((_, i) => (
                <button
                  key={i}
                  className={`btn ${i === activeTab ? 'btn-primary' : 'btn-secondary'}`}
                  onClick={() => setActiveTab(i)}
                  style={{ padding: '4px 12px', fontSize: 12 }}
                >
                  Batch {i + 1}
                </button>
              ))}
            </div>
          )}

          <div className="payload-preview">
            <pre>{JSON.stringify(preview.payloads[activeTab], null, 2)}</pre>
          </div>
        </>
      )}
    </div>
  );
}
