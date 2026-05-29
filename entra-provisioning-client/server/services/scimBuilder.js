const { v4: uuidv4 } = require('uuid');
const {
  SCIM_CORE_USER_SCHEMA,
  SCIM_ENTERPRISE_USER_SCHEMA,
  SCIM_BULK_REQUEST_SCHEMA,
} = require('../schemas/scimSchemas');

/**
 * Build a SCIM BulkRequest payload from CSV rows and attribute mapping.
 *
 * @param {Object[]} rows - Array of CSV row objects
 * @param {Object} mapping - Attribute mapping config: { scimAttribute: csvColumn, ... }
 * @param {string} [customSchemaNamespace] - Optional custom SCIM schema namespace
 * @param {number} [operationsPerRequest=50] - Max operations per bulk request
 * @param {Object} [customAttributeTypes] - Optional type map: { attrName: 'string'|'dateTime'|'integer'|'boolean' }
 * @returns {Object[]} Array of SCIM BulkRequest payloads
 */
function buildScimBulkPayloads(rows, mapping, customSchemaNamespace = null, operationsPerRequest = 50, customAttributeTypes = null) {
  const payloads = [];
  let currentOps = [];

  for (const row of rows) {
    const userData = buildUserData(row, mapping, customSchemaNamespace, customAttributeTypes);
    const operation = {
      method: 'POST',
      bulkId: uuidv4(),
      path: '/Users',
      data: userData,
    };
    currentOps.push(operation);

    if (currentOps.length >= operationsPerRequest) {
      payloads.push(wrapBulkRequest(currentOps));
      currentOps = [];
    }
  }

  if (currentOps.length > 0) {
    payloads.push(wrapBulkRequest(currentOps));
  }

  return payloads;
}

function wrapBulkRequest(operations) {
  return {
    schemas: [SCIM_BULK_REQUEST_SCHEMA],
    Operations: operations,
    failOnErrors: null,
  };
}

/**
 * Build a single SCIM user data object from a CSV row using the mapping.
 */
function buildUserData(row, mapping, customSchemaNamespace, customAttributeTypes) {
  const schemas = [SCIM_CORE_USER_SCHEMA];
  const data = { schemas };

  // Track which schemas we need
  let hasEnterpriseAttrs = false;
  let hasCustomAttrs = false;

  for (const [scimPath, csvColumn] of Object.entries(mapping)) {
    if (!csvColumn || csvColumn === '') continue;

    const value = row[csvColumn];
    if (value === undefined || value === null || value === '') continue;

    // Parse the SCIM path: e.g. "name.givenName", "enterprise.department", "addresses[0].streetAddress"
    if (scimPath.startsWith('enterprise.')) {
      hasEnterpriseAttrs = true;
      const attrName = scimPath.substring('enterprise.'.length);
      if (!data[SCIM_ENTERPRISE_USER_SCHEMA]) {
        data[SCIM_ENTERPRISE_USER_SCHEMA] = {};
      }
      setNestedValue(data[SCIM_ENTERPRISE_USER_SCHEMA], attrName, value);
    } else if (scimPath.startsWith('custom.')) {
      hasCustomAttrs = true;
      const attrName = scimPath.substring('custom.'.length);
      const ns = customSchemaNamespace || 'urn:ietf:params:scim:schemas:extension:csv:1.0:User';
      if (!data[ns]) {
        data[ns] = {};
      }
      // Apply type coercion for custom attributes
      const attrType = customAttributeTypes && customAttributeTypes[attrName];
      data[ns][attrName] = coerceCustomValue(value, attrType);
    } else if (scimPath === 'active') {
      // Handle boolean conversion
      data.active = toBool(value);
    } else {
      setNestedValue(data, scimPath, value);
    }
  }

  if (hasEnterpriseAttrs && !schemas.includes(SCIM_ENTERPRISE_USER_SCHEMA)) {
    schemas.push(SCIM_ENTERPRISE_USER_SCHEMA);
  }

  if (hasCustomAttrs) {
    const ns = customSchemaNamespace || 'urn:ietf:params:scim:schemas:extension:csv:1.0:User';
    if (!schemas.includes(ns)) {
      schemas.push(ns);
    }
  }

  return data;
}

/**
 * Set a value in a nested object using dot notation.
 * Handles paths like "name.givenName" → { name: { givenName: value } }
 * and array paths like "addresses.0.streetAddress"
 */
function setNestedValue(obj, path, value) {
  const parts = path.split('.');
  let current = obj;

  for (let i = 0; i < parts.length - 1; i++) {
    const part = parts[i];
    const nextPart = parts[i + 1];

    if (!isNaN(nextPart)) {
      // Next part is array index
      if (!Array.isArray(current[part])) {
        current[part] = [];
      }
    } else if (!isNaN(part)) {
      // Current part is array index
      const idx = parseInt(part, 10);
      while (current.length <= idx) {
        current.push({});
      }
      current = current[idx];
      continue;
    } else {
      if (!current[part] || typeof current[part] !== 'object') {
        current[part] = {};
      }
    }
    current = current[part];
  }

  const lastPart = parts[parts.length - 1];
  if (!isNaN(lastPart)) {
    // Shouldn't end with index, but handle gracefully
    current[parseInt(lastPart, 10)] = value;
  } else {
    current[lastPart] = value;
  }
}

function toBool(val) {
  if (typeof val === 'boolean') return val;
  if (typeof val === 'string') {
    const lower = val.toLowerCase().trim();
    return lower === 'true' || lower === 'yes' || lower === '1' || lower === 'active';
  }
  return Boolean(val);
}

/**
 * Coerce a custom attribute value based on declared type.
 */
function coerceCustomValue(value, type) {
  if (!type || type === 'string') return String(value);
  if (type === 'boolean') return toBool(value);
  if (type === 'integer') {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? value : parsed;
  }
  if (type === 'dateTime') {
    // If already ISO format, keep it; otherwise try to parse
    const d = new Date(value);
    return isNaN(d.getTime()) ? String(value) : d.toISOString();
  }
  return String(value);
}

module.exports = { buildScimBulkPayloads };
