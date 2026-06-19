/**
 * SCIM Schema definitions for Core User and Enterprise User.
 * Used for attribute mapping validation and UI rendering.
 */

const SCIM_CORE_USER_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:User';
const SCIM_ENTERPRISE_USER_SCHEMA = 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User';
const SCIM_BULK_REQUEST_SCHEMA = 'urn:ietf:params:scim:api:messages:2.0:BulkRequest';

/**
 * Flat list of all standard SCIM attributes that customers can map to.
 * Organized by schema namespace.
 */
const SCIM_ATTRIBUTES = {
  [SCIM_CORE_USER_SCHEMA]: {
    simple: [
      { name: 'externalId', type: 'string', required: true, description: 'Unique identifier from source system' },
      { name: 'userName', type: 'string', required: true, description: 'Unique username for the user' },
      { name: 'displayName', type: 'string', required: false, description: 'Display name' },
      { name: 'nickName', type: 'string', required: false, description: 'Casual name' },
      { name: 'title', type: 'string', required: false, description: 'Job title' },
      { name: 'userType', type: 'string', required: false, description: 'User type (Employee, Contractor, etc.)' },
      { name: 'preferredLanguage', type: 'string', required: false, description: 'Preferred language (e.g. en-US)' },
      { name: 'locale', type: 'string', required: false, description: 'Locale for formatting' },
      { name: 'timezone', type: 'string', required: false, description: 'Timezone (e.g. America/Los_Angeles)' },
      { name: 'active', type: 'boolean', required: false, description: 'Whether user is active' },
    ],
    complex: [
      {
        name: 'name', type: 'complex', description: 'User name components',
        subAttributes: [
          { name: 'familyName', type: 'string', description: 'Last name' },
          { name: 'givenName', type: 'string', description: 'First name' },
          { name: 'middleName', type: 'string', description: 'Middle name' },
          { name: 'honorificPrefix', type: 'string', description: 'Title prefix (Mr., Ms., Dr.)' },
          { name: 'honorificSuffix', type: 'string', description: 'Title suffix (Jr., III)' },
          { name: 'formatted', type: 'string', description: 'Full formatted name' },
        ]
      },
      {
        name: 'emails', type: 'complex', multiValued: true, description: 'Email addresses',
        subAttributes: [
          { name: 'value', type: 'string', description: 'Email address' },
          { name: 'type', type: 'string', description: 'Type (work, home, other)' },
          { name: 'primary', type: 'boolean', description: 'Is primary email' },
        ]
      },
      {
        name: 'phoneNumbers', type: 'complex', multiValued: true, description: 'Phone numbers',
        subAttributes: [
          { name: 'value', type: 'string', description: 'Phone number' },
          { name: 'type', type: 'string', description: 'Type (work, home, mobile, fax)' },
          { name: 'primary', type: 'boolean', description: 'Is primary phone' },
        ]
      },
      {
        name: 'addresses', type: 'complex', multiValued: true, description: 'Physical addresses',
        subAttributes: [
          { name: 'streetAddress', type: 'string', description: 'Street address' },
          { name: 'locality', type: 'string', description: 'City' },
          { name: 'region', type: 'string', description: 'State/Region' },
          { name: 'postalCode', type: 'string', description: 'Postal/Zip code' },
          { name: 'country', type: 'string', description: 'Country' },
          { name: 'type', type: 'string', description: 'Type (work, home, other)' },
          { name: 'formatted', type: 'string', description: 'Full formatted address' },
        ]
      },
    ]
  },
  [SCIM_ENTERPRISE_USER_SCHEMA]: {
    simple: [
      { name: 'employeeNumber', type: 'string', required: false, description: 'Employee number' },
      { name: 'costCenter', type: 'string', required: false, description: 'Cost center' },
      { name: 'organization', type: 'string', required: false, description: 'Organization' },
      { name: 'division', type: 'string', required: false, description: 'Division' },
      { name: 'department', type: 'string', required: false, description: 'Department' },
    ],
    complex: [
      {
        name: 'manager', type: 'complex', description: 'Manager',
        subAttributes: [
          { name: 'value', type: 'string', description: 'Manager external ID' },
          { name: 'displayName', type: 'string', description: 'Manager display name' },
        ]
      }
    ]
  }
};

module.exports = {
  SCIM_CORE_USER_SCHEMA,
  SCIM_ENTERPRISE_USER_SCHEMA,
  SCIM_BULK_REQUEST_SCHEMA,
  SCIM_ATTRIBUTES,
};
