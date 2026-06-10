/**
 * Validate a client-supplied Microsoft Graph provisioning endpoint before a
 * bearer token is attached to a request to it. This prevents SSRF /
 * token-exfiltration where a malicious or mistyped endpoint would receive a
 * freshly acquired Graph access token.
 *
 * Rules enforced (via URL parsing — never substring matching):
 *   - protocol must be https:
 *   - hostname must be in the allowlist of Microsoft Graph hosts (incl. national clouds)
 *   - path must end with /bulkUpload (case-insensitive)
 *
 * The host allowlist defaults to the public + national cloud Graph endpoints and
 * can be overridden via the GRAPH_ALLOWED_HOSTS env var (comma-separated).
 */

const DEFAULT_ALLOWED_HOSTS = [
  'graph.microsoft.com',
  'graph.microsoft.us',
  'dod-graph.microsoft.us',
  'microsoftgraph.chinacloudapi.cn',
];

function getAllowedHosts() {
  const fromEnv = (process.env.GRAPH_ALLOWED_HOSTS || '')
    .split(',')
    .map(h => h.trim().toLowerCase())
    .filter(Boolean);
  return fromEnv.length > 0 ? fromEnv : DEFAULT_ALLOWED_HOSTS;
}

/**
 * Validate a Graph bulkUpload endpoint URL.
 * @param {string} endpoint
 * @returns {{ valid: boolean, error?: string }}
 */
function validateGraphEndpoint(endpoint) {
  if (!endpoint || typeof endpoint !== 'string') {
    return { valid: false, error: 'Provisioning API endpoint is required.' };
  }

  let parsed;
  try {
    parsed = new URL(endpoint);
  } catch {
    return { valid: false, error: 'Provisioning API endpoint is not a valid URL.' };
  }

  if (parsed.protocol !== 'https:') {
    return { valid: false, error: 'Provisioning API endpoint must use HTTPS.' };
  }

  const allowedHosts = getAllowedHosts();
  const host = parsed.hostname.toLowerCase();
  if (!allowedHosts.includes(host)) {
    return {
      valid: false,
      error: `Provisioning API endpoint host '${parsed.hostname}' is not an allowed Microsoft Graph host. Allowed hosts: ${allowedHosts.join(', ')}.`,
    };
  }

  if (!parsed.pathname.toLowerCase().endsWith('/bulkupload')) {
    return {
      valid: false,
      error: "Provisioning API endpoint must be a Microsoft Graph bulkUpload URL (path ending in '/bulkUpload').",
    };
  }

  return { valid: true };
}

module.exports = { validateGraphEndpoint, DEFAULT_ALLOWED_HOSTS };
