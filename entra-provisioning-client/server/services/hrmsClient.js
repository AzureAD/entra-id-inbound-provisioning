/**
 * HRMS API Client Service
 * 
 * Generic service that fetches data from any HRMS system based on
 * connector configuration. Handles OAuth2, Basic, API Key, and Bearer auth.
 * Supports pagination and JSON path resolution.
 */

/**
 * Resolve a dot-notation path on a JSON object.
 * e.g. resolvePath({ d: { results: [1,2,3] } }, 'd.results') → [1,2,3]
 */
function resolvePath(obj, path) {
  if (!path) return obj;
  return path.split('.').reduce((acc, key) => {
    if (acc == null) return null;
    return acc[key];
  }, obj);
}

/**
 * Build Authorization header based on auth type.
 */
async function getAuthHeader(connectorConfig) {
  const authType = connectorConfig.authType || 'none';

  switch (authType) {
    case 'none':
      return {};

    case 'basic': {
      const creds = connectorConfig.username && connectorConfig.password
        ? `${connectorConfig.username}:${connectorConfig.password}`
        : (connectorConfig.authValue || '');
      const encoded = Buffer.from(creds).toString('base64');
      return { 'Authorization': `Basic ${encoded}` };
    }

    case 'bearer':
      return { 'Authorization': `Bearer ${connectorConfig.authValue}` };

    case 'apikey':
      // BambooHR uses basic auth with apikey:x
      return { 'Authorization': `Basic ${Buffer.from(connectorConfig.apiKey + ':x').toString('base64')}` };

    case 'oauth2': {
      const token = await fetchOAuth2Token(connectorConfig);
      return { 'Authorization': `Bearer ${token}` };
    }

    default:
      return {};
  }
}

/**
 * Fetch an OAuth2 access token using client credentials grant.
 */
async function fetchOAuth2Token(config) {
  const { tokenUrl, clientId, clientSecret } = config;
  if (!tokenUrl || !clientId || !clientSecret) {
    throw new Error('OAuth2 requires tokenUrl, clientId, and clientSecret');
  }

  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: clientId,
    client_secret: clientSecret,
  });

  const res = await fetch(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OAuth2 token request failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  return data.access_token;
}

/**
 * Flatten a nested object into a single-level key→value map.
 * { "name": { "first": "John" } } → { "name.first": "John" }
 * Arrays are flattened with numeric indices.
 */
function flattenObject(obj, prefix = '', result = {}) {
  for (const [key, value] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenObject(value, path, result);
    } else if (Array.isArray(value)) {
      // For arrays, take first element's value for field discovery
      if (value.length > 0 && typeof value[0] === 'object') {
        flattenObject(value[0], `${path}.0`, result);
      } else {
        result[path] = value.length > 0 ? String(value[0]) : '';
      }
    } else {
      result[path] = value != null ? String(value) : '';
    }
  }
  return result;
}

/**
 * Fetch data from an HRMS connector.
 * Returns { headers: string[], rows: object[], totalFetched: number }
 */
async function fetchHRMSData(connectorDef, connectorConfig, maxRecords = 1000) {
  const authHeaders = await getAuthHeader(connectorConfig);
  const responseMapping = connectorDef.responseMapping || {};

  // Build the URL
  let baseUrl = connectorConfig.baseUrl.replace(/\/+$/, '');
  const endpointPath = connectorConfig.endpoint || connectorConfig.workersEndpoint || connectorDef.configFields.find(f => f.key === 'workersEndpoint')?.default || '';
  const entity = connectorConfig.entity || connectorDef.configFields.find(f => f.key === 'entity')?.default || '';
  
  let url = baseUrl;
  if (endpointPath) url += endpointPath;
  if (entity) url += `/${entity}`;

  // Add select fields if available
  const selectFields = connectorConfig.selectFields;
  if (selectFields) {
    const sep = url.includes('?') ? '&' : '?';
    url += `${sep}$select=${selectFields}`;
  }

  // Parse custom headers
  let customHeaders = {};
  if (connectorConfig.headers) {
    try {
      customHeaders = typeof connectorConfig.headers === 'string'
        ? JSON.parse(connectorConfig.headers)
        : connectorConfig.headers;
    } catch { /* ignore */ }
  }

  const headers = {
    'Accept': 'application/json',
    ...authHeaders,
    ...customHeaders,
  };

  const method = (connectorConfig.method || 'GET').toUpperCase();
  const allRows = [];
  let offset = 0;
  const pageSize = responseMapping.defaultPageSize || 100;
  const dataPath = connectorConfig.dataPath || responseMapping.dataPath;

  // Fetch with pagination (or single request if no pagination)
  let hasMore = true;
  while (hasMore && allRows.length < maxRecords) {
    let pageUrl = url;
    if (responseMapping.pagingParam && responseMapping.pageSizeParam) {
      const sep = pageUrl.includes('?') ? '&' : '?';
      pageUrl += `${sep}${responseMapping.pageSizeParam}=${pageSize}&${responseMapping.pagingParam}=${offset}`;
    }

    const res = await fetch(pageUrl, { method, headers });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`HRMS API request failed (${res.status}): ${text.substring(0, 500)}`);
    }

    const json = await res.json();
    const records = resolvePath(json, dataPath);

    if (!records || !Array.isArray(records) || records.length === 0) {
      hasMore = false;
      break;
    }

    allRows.push(...records);
    offset += records.length;

    // Check if there are more pages
    if (!responseMapping.pagingParam || records.length < pageSize) {
      hasMore = false;
    }
  }

  if (allRows.length === 0) {
    throw new Error('No records returned from the HRMS API. Check your configuration and endpoint.');
  }

  // Flatten nested objects to get tabular data
  const flatRows = allRows.map(row => flattenObject(row));

  // Extract all unique keys as headers
  const headerSet = new Set();
  flatRows.forEach(row => Object.keys(row).forEach(k => headerSet.add(k)));
  const headerList = Array.from(headerSet).sort();

  // Normalize rows to ensure all headers present
  const normalizedRows = flatRows.map(row => {
    const normalized = {};
    headerList.forEach(h => { normalized[h] = row[h] || ''; });
    return normalized;
  });

  return {
    headers: headerList,
    rows: normalizedRows,
    totalFetched: normalizedRows.length,
  };
}

/**
 * Test connectivity to an HRMS system by fetching a small sample.
 */
async function testConnection(connectorDef, connectorConfig) {
  try {
    const result = await fetchHRMSData(connectorDef, connectorConfig, 2);
    return {
      success: true,
      message: `Connected successfully. Found ${result.headers.length} fields and ${result.totalFetched} sample records.`,
      sampleHeaders: result.headers.slice(0, 20),
      sampleRow: result.rows[0],
    };
  } catch (err) {
    return {
      success: false,
      message: err.message,
    };
  }
}

module.exports = { fetchHRMSData, testConnection, flattenObject };
