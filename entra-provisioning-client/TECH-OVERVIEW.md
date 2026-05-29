# Entra Provisioning Client — Technical Overview

## What Is It?
A **local-run web application** that converts employee data (from CSV files or HRMS APIs) into **SCIM 2.0 BulkRequest** payloads and POSTs them to the **Microsoft Entra ID Inbound Provisioning API**. It provides a guided 6-step wizard UI so admins can connect, import, map, preview, and send user data without writing code or PowerShell scripts.

---

## Architecture at a Glance

```
┌─────────────────────────────────┐       ┌───────────────────────────────────┐
│        React 18 Frontend        │  API  │        Express 4.18 Backend       │
│   (Single-Page App, port 3000)  │ ───►  │       (REST API, port 3001)       │
│                                 │       │                                   │
│  6-step wizard:                 │       │  /api/upload      CSV parse       │
│  Connect → Source → Data →      │       │  /api/mapping     SCIM schema     │
│  Map → Preview → Send           │       │  /api/provisioning SCIM build/send│
│                                 │       │  /api/connectors  HRMS registry   │
└─────────────────────────────────┘       └──────────┬────────────────────────┘
                                                     │
                                          ┌──────────▼──────────┐
                                          │  Entra ID / HRMS    │
                                          │  (external APIs)    │
                                          └─────────────────────┘
```

**In production mode**, the Express server also serves the React build as static files from a single port (3001), so no separate web server is needed.

---

## Tech Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Runtime** | Node.js | 20+ | Server & build toolchain |
| **Backend** | Express | 4.18.2 | REST API framework |
| **Frontend** | React | 18.2 | SPA UI (create-react-app) |
| **Auth SDK** | @azure/identity | 4.2 | OAuth2 client-credentials flow for Entra ID |
| **CSV Parsing** | csv-parse | 5.5.3 | Stream-based CSV-to-JSON with BOM support |
| **File Upload** | Multer | 1.4.5 | Multipart form handling (50 MB limit, memory storage) |
| **Unique IDs** | uuid v4 | 9.0 | SCIM `bulkId` generation |
| **Dev Tooling** | concurrently | 8.2 | Run server + client dev servers in parallel |
| **Containerization** | Docker | Multi-stage Alpine | Production image (~150 MB) |

No database. No external state. All data lives in-memory (`app.locals`) for the duration of a session.

---

## Server Components (Express — `server/`)

### Routes
| Route | File | Verb(s) | What it does |
|-------|------|---------|-------------|
| `/api/upload` | `routes/upload.js` | POST, GET | Accepts CSV upload (Multer), parses via csv-parse, stores rows in `app.locals.csvData`. GET returns stored data. |
| `/api/mapping/schema` | `routes/mapping.js` | GET | Returns the full SCIM attribute catalogue (Core User + Enterprise User). |
| `/api/mapping/validate` | `routes/mapping.js` | POST | Validates a mapping object against uploaded CSV headers; enforces `externalId` as required. |
| `/api/provisioning/preview` | `routes/provisioning.js` | POST | Builds SCIM BulkRequest JSON from rows + mapping without sending. Returns payload array. |
| `/api/provisioning/send` | `routes/provisioning.js` | POST | Acquires OAuth2 token → builds payloads → POSTs each batch to Entra bulkUpload endpoint. Returns per-batch results. |
| `/api/connectors` | `routes/connectors.js` | GET | Lists all registered HRMS connectors. |
| `/api/connectors/:id` | `routes/connectors.js` | GET | Returns a single connector's config schema & field hints. |
| `/api/connectors/:id/test` | `routes/connectors.js` | POST | Tests connectivity to an HRMS (HEAD/GET probe). |
| `/api/connectors/:id/fetch` | `routes/connectors.js` | POST | Fetches employee records from HRMS API, flattens nested JSON, stores as `csvData`. |

### Services
| Service | File | Responsibility |
|---------|------|----------------|
| **csvParser** | `services/csvParser.js` | Wraps `csv-parse` in a Promise; returns `{ headers, rows }`. |
| **scimBuilder** | `services/scimBuilder.js` | Converts flat row objects + mapping into SCIM User resources. Handles dot-notation paths (`name.givenName`), enterprise attributes, custom schema namespaces, and boolean coercion. Chunks into BulkRequest payloads (default 50 ops/request). |
| **entraAuth** | `services/entraAuth.js` | `getAccessToken()` — uses `ClientSecretCredential` (client-credentials grant) to fetch a token scoped to `https://graph.microsoft.com/.default`. `sendBulkUpload()` — POSTs payload with `Content-Type: application/scim+json`. |
| **hrmsClient** | `services/hrmsClient.js` | Generic HTTP client for any HRMS API. Supports OAuth2, Basic, API Key, and Bearer auth types. Handles pagination, JSON-path data extraction (`d.results`, `data.employees`), and recursive object flattening. |

### Connector Registry (`server/connectors/registry.js`)
Pre-built connector definitions for **6 HRMS systems**:

| Connector | Auth Type | Key Fields |
|-----------|-----------|------------|
| Workday | OAuth2 | REST Workers endpoint, tenant URL |
| SAP SuccessFactors | Basic Auth | OData User endpoint, company ID |
| BambooHR | API Key | Subdomain, API key |
| ADP Workforce Now | OAuth2 | Client cert endpoint |
| Oracle HCM Cloud | Basic Auth | REST Workers URL |
| Custom REST API | Configurable | Any URL, any auth |

Each connector defines: `id`, `name`, `description`, `icon`, `category`, `authType`, `configFields[]`, `responseMapping` (data path + pagination), and `sampleFieldHints`.

### SCIM Schema (`server/schemas/scimSchemas.js`)
Exports:
- `SCIM_CORE_USER_SCHEMA` = `urn:ietf:params:scim:schemas:core:2.0:User`
- `SCIM_ENTERPRISE_USER_SCHEMA` = `urn:ietf:params:scim:schemas:extension:enterprise:2.0:User`
- `SCIM_BULK_REQUEST_SCHEMA` = `urn:ietf:params:scim:api:messages:2.0:BulkRequest`
- `SCIM_ATTRIBUTES[]` — flat array of attribute definitions, each with `scimPath`, `displayName`, `description`, `type`, `required`, `category` (Core User / Enterprise User), and `subAttributes` for complex types (name, emails, phoneNumbers, addresses).

---

## Client Components (React 18 — `client/`)

### Application Shell (`App.js`)
- **State management**: React `useState` hooks — no Redux/Context needed at MVP scale.
- **Wizard flow**: Renders one of six step-components based on `currentStep` (0–5).
- **Stepper bar**: Horizontal numbered step indicators with active/completed states.

### Components
| Component | Step | What it does |
|-----------|------|-------------|
| `ConnectionConfig.js` | 0 — Connect | Form for Tenant ID, Client ID, Client Secret, Provisioning API Endpoint. Shows a security banner ("credentials stay local"). Validates all 4 fields before proceeding. |
| `DataSourcePicker.js` | 1 — Source | Two-card selector: **CSV Upload** or **HRMS Integration**. Sets `dataSource` state to `'csv'` or `'hrms'`. |
| `FileUpload.js` | 2 — Data (CSV) | Drag-and-drop zone + click-to-browse. Shows filename, row count, and a 5-row preview table after upload. Calls `POST /api/upload`. |
| `HRMSConnector.js` | 2 — Data (HRMS) | Grid of connector cards → config form (dynamic fields from registry) → Test Connection → Fetch Data. Calls `/api/connectors` routes. |
| `AttributeMapping.js` | 3 — Map | Two-column mapping table: SCIM attribute ↔ source column dropdown. **Auto-Map** button does fuzzy name matching. Required fields flagged. Calls `/api/mapping/schema` and `/api/mapping/validate`. |
| `PayloadPreview.js` | 4 — Preview | Generates and displays the SCIM BulkRequest JSON. Shows operation count and batch count. Copy-to-clipboard and Download buttons. Calls `/api/provisioning/preview`. |
| `SubmitResult.js` | 5 — Send | Sends payloads to Entra ID. Per-batch progress with status badges. Calls `/api/provisioning/send`. |

### API Layer (`services/api.js`)
Thin wrapper around `fetch()` — no Axios or other library. Functions: `uploadCsv`, `getScimSchema`, `validateMapping`, `previewPayload`, `sendToApi`, `getConnectors`, `getConnectorDetails`, `testHRMSConnection`, `fetchHRMSData`. All point to relative `/api/...` paths (proxied in dev via CRA `proxy` setting).

### Styling
- Single `App.css` file — ~600 lines, custom CSS (no UI library).
- Fluent UI-inspired design language with CSS variables for theming.
- Responsive breakpoint at 480px for mobile.

---

## Security Model
| Concern | How it's handled |
|---------|-----------------|
| Credentials at rest | Never written to disk; held in React state + passed per-request to server |
| Network exposure | Server binds to `127.0.0.1` only — not reachable from the network |
| Token lifetime | `ClientSecretCredential` acquires a short-lived token per send operation |
| Data in transit (local) | HTTP between browser and localhost (TLS optional, same-machine only) |
| .env file | `.gitignore`'d — never committed; `.env.example` shipped as template |

---

## Data Flow (end-to-end)

```
1. User enters Entra app credentials (Tenant, Client ID/Secret, Endpoint)
2. User picks data source: CSV file  OR  HRMS connector
3. CSV → Multer → csv-parse → { headers, rows } stored in app.locals
   HRMS → HTTP fetch + flatten → { headers, rows } stored in app.locals
4. SCIM attribute schema loaded from scimSchemas.js → UI renders mapping table
5. User maps source columns to SCIM attributes (or clicks Auto-Map)
6. scimBuilder converts rows → SCIM User objects → chunks into BulkRequest payloads
7. Preview JSON shown in UI
8. On Send:
   a. ClientSecretCredential acquires OAuth2 token (graph.microsoft.com scope)
   b. Each BulkRequest payload POSTed to the provisioning endpoint
      with Content-Type: application/scim+json
   c. Per-batch HTTP status returned to UI
```

---

## Deployment Options

| Method | Command | Notes |
|--------|---------|-------|
| **One-command (Windows)** | `setup.bat` | Checks Node ≥ 18, installs deps, builds React, starts server |
| **One-command (macOS/Linux)** | `./setup.sh` | Same as above |
| **Dev mode** | `npm run dev` | Starts Express (3001) + CRA dev server (3000) via concurrently |
| **Docker** | `docker compose up --build` | Multi-stage Alpine image, single port 3001 |
| **Production** | `npm run build && npm start` | Express serves React build as static files |

---

## Key Design Decisions
1. **No database** — MVP simplicity; state resets on server restart.
2. **In-memory storage** (`app.locals`) — single-user, single-session by design.
3. **No UI framework** (no Fluent UI / MUI) — keeps bundle tiny (53.6 kB JS gzipped) and avoids dependency churn.
4. **Extensible connector registry** — add a new HRMS by adding a JSON object to `registry.js`; no code changes needed.
5. **Server binds to localhost** — this is a local tool, not a hosted service.
6. **create-react-app** — zero-config React setup; ejectable if needed later.

---

## File Count & Size
- **33 files** committed
- **3,409 lines** of code (all hand-written, no generated boilerplate beyond CRA)
- React production build: **53.6 kB** JS + **2.3 kB** CSS (gzipped)

---

## Prerequisites for Running
- **Node.js 18+** (20 recommended)
- **Entra ID app registration** with:
  - `SynchronizationData-User.Upload` application permission (admin-consented)
  - Client secret generated
  - Provisioning job bulkUpload endpoint URL
