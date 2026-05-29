import React, { useRef, useState } from 'react';
import { uploadCsv } from '../services/api';

export default function FileUpload({ onUploadComplete }) {
  const [dragOver, setDragOver] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);
  const fileRef = useRef();

  const handleFile = async (file) => {
    if (!file) return;
    if (!file.name.endsWith('.csv') && !file.name.endsWith('.txt')) {
      setError('Please upload a CSV file (.csv or .txt)');
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await uploadCsv(file);
      setResult(data);
      onUploadComplete(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const onDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    handleFile(e.dataTransfer.files[0]);
  };

  return (
    <div className="card">
      <h2>Upload CSV File</h2>
      <p className="subtitle">Upload a CSV file containing your user data from any system of record.</p>

      <div
        className={`file-upload-zone ${dragOver ? 'dragover' : ''}`}
        onDragOver={e => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={onDrop}
        onClick={() => fileRef.current?.click()}
      >
        <div className="icon">📄</div>
        <p><strong>Drop your CSV file here</strong> or click to browse</p>
        <p style={{ fontSize: 12, marginTop: 8 }}>Supports .csv and .txt files up to 50MB</p>
        <input
          ref={fileRef}
          type="file"
          accept=".csv,.txt"
          style={{ display: 'none' }}
          onChange={e => handleFile(e.target.files[0])}
        />
      </div>

      {loading && (
        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <span className="spinner" /> <span style={{ marginLeft: 8 }}>Parsing file...</span>
        </div>
      )}

      {error && <div className="alert alert-error" style={{ marginTop: 16 }}>❌ {error}</div>}

      {result && (
        <>
          <div className="alert alert-success" style={{ marginTop: 16 }}>
            ✅ <strong>{result.fileName}</strong> — {result.totalRows} records, {result.headers.length} columns
          </div>

          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  {result.headers.map(h => <th key={h}>{h}</th>)}
                </tr>
              </thead>
              <tbody>
                {result.preview.map((row, i) => (
                  <tr key={i}>
                    {result.headers.map(h => <td key={h} title={row[h]}>{row[h]}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 8 }}>
            Showing first {result.preview.length} of {result.totalRows} rows
          </p>
        </>
      )}
    </div>
  );
}
