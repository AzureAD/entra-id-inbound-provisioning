/**
 * Update the provisioning job's attribute schema via Microsoft Graph API.
 * This automatically adds custom SCIM extension attributes and syncs standard
 * attribute mappings to the provisioning job schema so users don't need to
 * manually configure them in the Entra portal.
 */

/**
 * Default mapping of client SCIM paths to Entra ID target attribute names.
 * Used to ensure the provisioning app has mappings for all attributes the client sends.
 */
const STANDARD_MAPPING_DEFAULTS = {
  'externalId': 'employeeId',
  'userName': 'userPrincipalName',
  'displayName': 'displayName',
  'name.givenName': 'givenName',
  'name.familyName': 'surname',
  'name.middleName': null, // no standard Entra target
  'name.honorificPrefix': null,
  'name.honorificSuffix': null,
  'title': 'jobTitle',
  'active': 'accountEnabled',
  'userType': 'userType',
  'preferredLanguage': 'preferredLanguage',
  'locale': null,
  'timezone': null,
  'emails.0.value': 'mail',
  'phoneNumbers.0.value': 'telephoneNumber',
  'addresses.0.streetAddress': 'streetAddress',
  'addresses.0.locality': 'city',
  'addresses.0.region': 'state',
  'addresses.0.postalCode': 'postalCode',
  'addresses.0.country': 'country',
  'enterprise.department': 'department',
  'enterprise.organization': 'companyName',
  'enterprise.division': null,
  'enterprise.costCenter': null,
  'enterprise.employeeNumber': 'employeeId',
  'enterprise.manager.value': 'manager',
};

/**
 * Resolve a client SCIM path (e.g. "name.givenName", "enterprise.department")
 * to the actual source attribute name used in the sync job schema.
 */
function resolveSourceAttributeName(scimPath, sourceAttrNames) {
  // Direct match
  if (sourceAttrNames.has(scimPath)) return scimPath;

  // Name sub-attributes: name.givenName → try as-is or just "givenName"
  if (scimPath.startsWith('name.')) {
    const sub = scimPath.replace('name.', '');
    if (sourceAttrNames.has(sub)) return sub;
  }

  // Enterprise extension attributes: enterprise.department → full URN
  if (scimPath.startsWith('enterprise.')) {
    const sub = scimPath.replace('enterprise.', '');
    const urn = `urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:${sub}`;
    if (sourceAttrNames.has(urn)) return urn;
    if (sourceAttrNames.has(sub)) return sub;
  }

  // Multi-valued: emails.0.value → emails[type eq "work"].value
  const multiMatch = scimPath.match(/^(emails|phoneNumbers|addresses)\.0\.(\w+)$/);
  if (multiMatch) {
    const [, collection, sub] = multiMatch;
    for (const name of sourceAttrNames) {
      if (name.startsWith(collection) && name.includes(sub)) return name;
    }
  }

  return null;
}

/**
 * Parse servicePrincipalId and jobId from the bulkUpload endpoint URL.
 * Expected format: https://graph.microsoft.com/beta/servicePrincipals/{spId}/synchronization/jobs/{jobId}/bulkUpload
 */
function parseEndpointIds(endpoint) {
  const match = endpoint.match(
    /servicePrincipals\/([^/]+)\/synchronization\/jobs\/([^/]+)/i
  );
  if (!match) {
    throw new Error(
      'Could not parse servicePrincipalId and jobId from endpoint URL. ' +
      'Expected format: .../servicePrincipals/{id}/synchronization/jobs/{jobId}/bulkUpload'
    );
  }
  return { servicePrincipalId: match[1], jobId: match[2] };
}

/**
 * Fetch the current synchronization job schema from Graph API.
 */
async function getJobSchema(accessToken, servicePrincipalId, jobId) {
  const url = `https://graph.microsoft.com/beta/servicePrincipals/${encodeURIComponent(servicePrincipalId)}/synchronization/jobs/${encodeURIComponent(jobId)}/schema`;
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to fetch job schema (${response.status}): ${body}`);
  }

  return response.json();
}

/**
 * Update the synchronization job schema via Graph API.
 */
async function updateJobSchema(accessToken, servicePrincipalId, jobId, schema) {
  const url = `https://graph.microsoft.com/beta/servicePrincipals/${encodeURIComponent(servicePrincipalId)}/synchronization/jobs/${encodeURIComponent(jobId)}/schema`;
  const response = await fetch(url, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(schema),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to update job schema (${response.status}): ${body}`);
  }

  // 204 No Content on success
  return { status: response.status, statusText: response.statusText };
}

/**
 * Map our UI attribute types to Graph synchronization schema types.
 */
function mapAttributeType(uiType) {
  switch (uiType) {
    case 'boolean': return 'Boolean';
    case 'integer': return 'Integer';
    case 'dateTime': return 'DateTime';
    case 'string':
    default: return 'String';
  }
}

/**
 * Ensure custom attributes exist in the provisioning job schema AND sync
 * standard attribute mappings from the client to the provisioning app.
 *
 * @param {string} accessToken - Bearer token with Synchronization.ReadWrite.All
 * @param {string} endpoint - The bulkUpload endpoint URL
 * @param {Object} customAttributes - { namespace, attributes: [{ name, type, targetAttribute }] }
 * @param {Object} [mapping] - Client mapping dict { scimPath: csvColumn }. When provided,
 *   ensures the provisioning app has attribute mappings for all standard SCIM attributes the client sends.
 * @returns {Object} { updated, attributesAdded, mappingsAdded, message }
 */
async function ensureCustomSchemaAttributes(accessToken, endpoint, customAttributes, mapping) {
  const hasCustom = customAttributes?.namespace && customAttributes?.attributes?.length;
  const hasStandard = mapping && Object.keys(mapping).length > 0;

  if (!hasCustom && !hasStandard) {
    return { updated: false, attributesAdded: [], mappingsAdded: [], message: 'No attributes to sync.' };
  }

  const { servicePrincipalId, jobId } = parseEndpointIds(endpoint);

  // Fetch current schema
  const schema = await getJobSchema(accessToken, servicePrincipalId, jobId);

  // Find the API-sourced directory (the source where inbound SCIM data arrives).
  // This is typically named with a pattern like "API" or the custom schema namespace.
  // We look for a directory that has objects with the custom namespace in its name,
  // or we find the first non-Azure-AD directory.
  let sourceDir = schema.directories?.find(d =>
    d.name && d.name !== 'Azure Active Directory' && d.name !== 'Microsoft Entra ID'
  );

  if (!sourceDir) {
    throw new Error(
      'Could not find the API source directory in the job schema. ' +
      'Ensure the provisioning job is properly configured with an API-driven inbound source.'
    );
  }

  // Find the User object in the source directory
  let userObject = sourceDir.objects?.find(o =>
    o.name === 'User' || o.name === 'user'
  );

  if (!userObject) {
    throw new Error(
      `Could not find "User" object in source directory "${sourceDir.name}". ` +
      'Ensure the provisioning job has a User object in its schema.'
    );
  }

  // ---- Custom attribute definitions ----
  const attributesAdded = [];
  if (hasCustom) {
    const existingAttrNames = new Set(
      (userObject.attributes || []).map(a => a.name)
    );
    const namespace = customAttributes.namespace;

    for (const attr of customAttributes.attributes) {
      const fullAttrName = `${namespace}:${attr.name}`;
      if (!existingAttrNames.has(fullAttrName)) {
        userObject.attributes.push({
          name: fullAttrName,
          type: mapAttributeType(attr.type),
          mutability: 'ReadWrite',
          flowNullValues: false,
          required: false,
          caseExact: false,
          referencedObjects: [],
          metadata: [],
        });
        attributesAdded.push(fullAttrName);
      }
    }
  }

  // Step 2: Add attribute mappings to the synchronization rules.
  // This maps source attributes to target Entra ID attributes
  // so users don't need to manually configure mappings in the portal.
  const mappingsAdded = [];

  const syncRule = schema.synchronizationRules?.[0];
  if (syncRule) {
    // Find the User-to-User object mapping
    const userMapping = syncRule.objectMappings?.find(m =>
      m.sourceObjectName === 'User' && m.targetObjectName === 'User'
    );

    if (userMapping) {
      if (!userMapping.attributeMappings) userMapping.attributeMappings = [];

      const existingTargets = new Set(
        userMapping.attributeMappings.map(m => m.targetAttributeName)
      );

      // ---- Standard attribute mappings ----
      if (hasStandard) {
        const sourceAttrNames = new Set(
          (userObject.attributes || []).map(a => a.name)
        );

        for (const scimPath of Object.keys(mapping)) {
          if (scimPath.startsWith('custom.')) continue; // handled below

          const targetAttr = STANDARD_MAPPING_DEFAULTS[scimPath];
          if (!targetAttr) continue; // no known default Entra target

          const sourceAttrName = resolveSourceAttributeName(scimPath, sourceAttrNames);
          if (!sourceAttrName) continue; // source attribute not in schema

          // Skip if target is already mapped
          if (existingTargets.has(targetAttr)) continue;

          userMapping.attributeMappings.push({
            source: { name: sourceAttrName, type: 'Attribute', parameters: [] },
            targetAttributeName: targetAttr,
            defaultValue: null,
            exportMissingReferences: false,
            flowBehavior: 'FlowWhenChanged',
            flowType: 'Add',
            matchingPriority: 0,
            mappingType: 'Direct',
            expression: '',
          });
          existingTargets.add(targetAttr);
          mappingsAdded.push(`${sourceAttrName} → ${targetAttr}`);
        }
      }

      // ---- Custom attribute mappings ----
      if (hasCustom) {
        const namespace = customAttributes.namespace;
        for (const attr of customAttributes.attributes) {
          const targetAttr = attr.targetAttribute;
          if (!targetAttr) continue; // No target specified, skip mapping

          const fullSourceName = `${namespace}:${attr.name}`;
          if (existingTargets.has(targetAttr)) {
            // Update existing mapping source to point to our custom attribute
            const existingMapping = userMapping.attributeMappings.find(
              m => m.targetAttributeName === targetAttr
            );
            if (existingMapping) {
              existingMapping.source = {
                name: fullSourceName,
                type: 'Attribute',
                parameters: [],
              };
              existingMapping.mappingType = 'Direct';
              existingMapping.expression = '';
              mappingsAdded.push(`${fullSourceName} → ${targetAttr} (updated)`);
            }
          } else {
            userMapping.attributeMappings.push({
              source: { name: fullSourceName, type: 'Attribute', parameters: [] },
              targetAttributeName: targetAttr,
              defaultValue: null,
              exportMissingReferences: false,
              flowBehavior: 'FlowWhenChanged',
              flowType: 'Add',
              matchingPriority: 0,
              mappingType: 'Direct',
              expression: '',
            });
            existingTargets.add(targetAttr);
            mappingsAdded.push(`${fullSourceName} → ${targetAttr}`);
          }
        }
      }
    }
  }

  if (attributesAdded.length === 0 && mappingsAdded.length === 0) {
    return {
      updated: false,
      attributesAdded: [],
      mappingsAdded: [],
      message: 'All attributes and mappings already exist in the provisioning job schema.',
    };
  }

  // PUT the updated schema back
  await updateJobSchema(accessToken, servicePrincipalId, jobId, schema);

  const parts = [];
  if (attributesAdded.length > 0) parts.push(`Added ${attributesAdded.length} custom attribute(s) to source schema.`);
  if (mappingsAdded.length > 0) parts.push(`Configured ${mappingsAdded.length} attribute mapping(s).`);

  return {
    updated: true,
    attributesAdded,
    mappingsAdded,
    message: parts.join(' '),
  };
}

module.exports = {
  parseEndpointIds,
  ensureCustomSchemaAttributes,
};
