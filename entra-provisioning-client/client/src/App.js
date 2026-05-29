import React, { useState, useEffect } from 'react';
import ConnectionConfig from './components/ConnectionConfig';
import DataSourcePicker from './components/DataSourcePicker';
import FileUpload from './components/FileUpload';
import HRMSConnector from './components/HRMSConnector';
import AttributeMapping from './components/AttributeMapping';
import PayloadPreview from './components/PayloadPreview';
import SubmitResult from './components/SubmitResult';

const STEPS = [
  { label: 'Connect', icon: '🔗', desc: 'Configure credentials' },
  { label: 'Source', icon: '📂', desc: 'Choose data source' },
  { label: 'Data', icon: '📄', desc: 'Import records' },
  { label: 'Map', icon: '🔀', desc: 'Attribute mapping' },
  { label: 'Preview', icon: '👁️', desc: 'Review payload' },
  { label: 'Send', icon: '🚀', desc: 'Submit to Entra' },
];

const STORAGE_PREFIX = 'entra-prov-';

function loadState(key, fallback) {
  try {
    const raw = localStorage.getItem(STORAGE_PREFIX + key);
    return raw !== null ? JSON.parse(raw) : fallback;
  } catch { return fallback; }
}

export default function App() {
  const [step, setStep] = useState(() => loadState('step', 0));
  const [theme, setTheme] = useState(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('entra-prov-theme');
      if (saved) return saved;
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return 'light';
  });
  const [config, setConfig] = useState(() => {
    const saved = loadState('config', {
      tenantId: '',
      clientId: '',
      endpoint: '',
      authMethod: 'certificate',
    });
    // Migrate: default authMethod to certificate
    if (!saved.authMethod || saved.authMethod === 'managedIdentity') saved.authMethod = 'certificate';
    return saved;
  });
  const [dataSource, setDataSource] = useState(() => loadState('dataSource', null));
  const [csvData, setCsvData] = useState(null);
  const [mapping, setMapping] = useState(() => loadState('mapping', {}));
  const [customAttributes, setCustomAttributes] = useState(() => loadState('customAttributes', {
    enabled: false,
    namespace: 'urn:ietf:params:scim:schemas:extension:custom:1.0:User',
    attributes: [],
  }));

  // Persist state to localStorage
  useEffect(() => { localStorage.setItem(STORAGE_PREFIX + 'step', JSON.stringify(step)); }, [step]);
  useEffect(() => { localStorage.setItem(STORAGE_PREFIX + 'config', JSON.stringify(config)); }, [config]);
  useEffect(() => { localStorage.setItem(STORAGE_PREFIX + 'dataSource', JSON.stringify(dataSource)); }, [dataSource]);
  useEffect(() => { localStorage.setItem(STORAGE_PREFIX + 'mapping', JSON.stringify(mapping)); }, [mapping]);
  useEffect(() => { localStorage.setItem(STORAGE_PREFIX + 'customAttributes', JSON.stringify(customAttributes)); }, [customAttributes]);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('entra-prov-theme', theme);
  }, [theme]);

  const toggleTheme = () => setTheme(t => t === 'light' ? 'dark' : 'light');

  const canProceed = (s) => {
    switch (s) {
      case 0: {
        if (!config.endpoint) return false;
        const method = config.authMethod || 'certificate';
        if (method === 'certificate') return !!(config.tenantId && config.clientId && config.certificatePath);
        if (method === 'clientSecret') return !!(config.tenantId && config.clientId && config.clientSecret);
        return false;
      }
      case 1: return dataSource !== null;
      case 2: return csvData !== null;
      case 3: return Object.keys(mapping).length > 0 && mapping.externalId;
      case 4: return true;
      default: return false;
    }
  };

  const getStepStatus = (i) => {
    if (i === step) return 'active';
    if (i < step) return 'completed';
    return '';
  };

  return (
    <div className="app-shell">
      {/* Sidebar */}
      <nav className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-brand">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="32" height="32"><defs><linearGradient id="g1" x1="-555" y1="1012.773" x2="-555" y2="1025.516" gradientTransform="translate(564 1025.516) scale(1 -1)" gradientUnits="userSpaceOnUse"><stop offset="0" stopColor="#0294e4"/><stop offset="1" stopColor="#6df"/></linearGradient><linearGradient id="g2" x1="-558.241" y1="1020.123" x2="-558.241" y2="1007.516" gradientTransform="translate(564 1025.516) scale(1 -1)" gradientUnits="userSpaceOnUse"><stop offset="0" stopColor="#b3b2b3"/><stop offset=".375" stopColor="#afaeaf"/><stop offset=".763" stopColor="#a2a2a2"/><stop offset="1" stopColor="#979797"/></linearGradient><linearGradient id="g3" x1="-550.507" y1="1007.516" x2="-550.507" y2="1016.502" gradientTransform="translate(564 1025.516) scale(1 -1)" gradientUnits="userSpaceOnUse"><stop offset=".001" stopColor="#773adc"/><stop offset=".342" stopColor="#8b55e6"/><stop offset=".756" stopColor="#9f70f0"/><stop offset="1" stopColor="#a67af4"/></linearGradient></defs><path d="m17.986,8.75c-.059-1.978-1.543-3.621-3.504-3.88C14.361,2.086,12.025-.084,9.24.002c-2.216-.04-4.217,1.324-4.988,3.402C1.886,3.691.084,5.664.014,8.046c.106,2.692,2.37,4.791,5.062,4.694.15,0,.303-.007.445-.019h8.195c.073-.001.146-.012.216-.032,2.188-.015,3.975-1.752,4.054-3.938Z" fill="url(#g1)"/><g><path d="m9.851,17.572c-.013.248-.224.439-.472.427H2.139c-.248.012-.459-.179-.472-.427V5.821c.013-.248.224-.439.472-.427h7.24c.248-.012.459.179.472.427v11.751Z" fill="url(#g2)"/><path d="m2.87,10.786c-.024-.516.373-.954.889-.98h4.073c.516.026.913.465.889.98h0c.024.516-.374.954-.889.98H3.759c-.516-.026-.914-.464-.889-.98Z" fill="#003067"/><path d="m2.87,7.871c-.024-.516.373-.954.889-.98h4.073c.516.026.913.465.889.98h0c.024.516-.374.954-.889.98H3.759c-.516-.026-.914-.464-.889-.98Z" fill="#003067"/><circle cx="4.014" cy="7.871" r=".658" fill="#50e6ff"/><circle cx="4.014" cy="10.783" r=".658" fill="#50e6ff"/></g><g><circle cx="13.493" cy="13.507" r="4.493" fill="url(#g3)"/><g><path d="m15.257,12.903h-.685c-.223.004-.402.187-.398.411.003.218.18.395.398.398h1.483c.223,0,.404-.181.404-.404v-1.752c.004-.223-.175-.407-.398-.411s-.407.175-.411.398c0,.004,0,.009,0,.013v.404c-.509-.679-1.308-1.079-2.157-1.078-.796-.008-1.554.343-2.063.955-.14.174-.114.428.06.569.17.138.42.115.562-.052.356-.427.886-.67,1.441-.663.783,0,1.484.482,1.764,1.213Z" fill="#fff"/><path d="m11.337,15.599v-.404c.897,1.193,2.591,1.433,3.783.536.159-.12.305-.257.434-.408.145-.17.124-.425-.046-.57-.17-.145-.425-.124-.57.046h0c-.678.796-1.873.892-2.669.214-.203-.173-.367-.386-.481-.627h.627c.223.004.407-.175.411-.398s-.175-.407-.398-.411c-.004,0-.009,0-.013,0h-1.483c-.223,0-.404.181-.404.404h0v1.618c-.004.223.175.407.398.411s.407-.175.411-.398c0-.004,0-.009,0-.013h0Z" fill="#fff"/></g></g></svg>
            <div className="sidebar-brand-text">
              <h1>Entra Provisioning</h1>
              <p>Inbound API Client</p>
            </div>
          </div>
        </div>

        <div className="sidebar-nav">
          <div className="nav-label">Workflow</div>
          {STEPS.map((s, i) => (
            <div
              key={i}
              className={`nav-item ${getStepStatus(i)}`}
              onClick={() => {
                if (i <= step) setStep(i);
                else if (i === step + 1 && canProceed(step)) setStep(i);
              }}
            >
              <div className="nav-number">
                {i < step ? '✓' : i + 1}
              </div>
              <span className="nav-icon">{s.icon}</span>
              <span>{s.label}</span>
            </div>
          ))}
        </div>

        <div className="sidebar-footer">
          <span className="version-tag">v1.0.0</span>
          <button className="theme-toggle" onClick={toggleTheme}>
            {theme === 'light' ? '🌙' : '☀️'} {theme === 'light' ? 'Dark' : 'Light'}
          </button>
        </div>
      </nav>

      {/* Main Content */}
      <div className="main-content">
        <div className="main-topbar">
          <div className="topbar-title">
            <span className="step-icon">{STEPS[step].icon}</span>
            <h2>{STEPS[step].label}</h2>
            <span className="step-count">Step {step + 1} of {STEPS.length}</span>
          </div>
        </div>

        <div className="main-body">
          {step === 0 && (
            <ConnectionConfig config={config} setConfig={setConfig} />
          )}

          {step === 1 && (
            <DataSourcePicker selected={dataSource} onSelect={(src) => {
              setDataSource(src);
              setCsvData(null);
              setMapping({});
            }} />
          )}

          {step === 2 && dataSource === 'csv' && (
            <FileUpload onUploadComplete={(data) => setCsvData(data)} />
          )}

          {step === 2 && dataSource === 'hrms' && (
            <HRMSConnector onDataLoaded={(data) => setCsvData(data)} />
          )}

          {step === 3 && csvData && (
            <AttributeMapping
              csvHeaders={csvData.headers}
              mapping={mapping}
              setMapping={setMapping}
              customAttributes={customAttributes}
              setCustomAttributes={setCustomAttributes}
            />
          )}

          {step === 4 && (
            <PayloadPreview mapping={mapping} customAttributes={customAttributes} />
          )}

          {step === 5 && (
            <SubmitResult mapping={mapping} config={config} customAttributes={customAttributes} />
          )}
        </div>

        {/* Bottom Action Bar */}
        <div className="bottom-bar">
          <div className="bottom-bar-inner">
            <button
              className="btn btn-secondary"
              onClick={() => setStep(Math.max(0, step - 1))}
              disabled={step === 0}
            >
              ← Back
            </button>
            <div className="bottom-bar-progress">
              {STEPS.map((_, i) => (
                <div key={i} className={`progress-dot ${i < step ? 'done' : ''} ${i === step ? 'current' : ''}`} />
              ))}
            </div>
            {step < STEPS.length - 1 ? (
              <button
                className="btn btn-primary btn-next"
                onClick={() => setStep(step + 1)}
                disabled={!canProceed(step)}
              >
                Continue →
              </button>
            ) : (
              <div style={{ width: 120 }} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
