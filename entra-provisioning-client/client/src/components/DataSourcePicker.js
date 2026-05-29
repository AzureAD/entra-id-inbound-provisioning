import React from 'react';

/**
 * DataSourcePicker — Step 1.5 between Connect and data ingestion.
 * User chooses: CSV Upload or HRMS Integration.
 */
export default function DataSourcePicker({ selected, onSelect }) {
  return (
    <div className="card">
      <h2>Choose Data Source</h2>
      <p className="subtitle">Select how you want to bring in your employee data.</p>

      <div className="source-grid">
        {/* CSV Option */}
        <div
          className={`source-card ${selected === 'csv' ? 'selected' : ''}`}
          onClick={() => onSelect('csv')}
        >
          <div className="source-icon">📄</div>
          <h3>CSV / File Upload</h3>
          <p>Upload a CSV or text file exported from any system of record.</p>
          <ul className="source-features">
            <li>Drag-and-drop upload</li>
            <li>Auto-detect columns</li>
            <li>Preview data before mapping</li>
          </ul>
          {selected === 'csv' && <div className="source-check">✓</div>}
        </div>

        {/* HRMS Option */}
        <div
          className={`source-card ${selected === 'hrms' ? 'selected' : ''}`}
          onClick={() => onSelect('hrms')}
        >
          <div className="source-icon">🔌</div>
          <h3>HRMS / API Integration</h3>
          <p>Connect directly to your HR system and pull employee data via API.</p>
          <ul className="source-features">
            <li>Workday, SAP SF, BambooHR, ADP, Oracle, and more</li>
            <li>Custom REST API support</li>
            <li>Automatic field discovery</li>
          </ul>
          {selected === 'hrms' && <div className="source-check">✓</div>}
        </div>
      </div>
    </div>
  );
}
