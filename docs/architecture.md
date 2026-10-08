# WaterQueue Architecture

## System Overview

```
┌─────────────────┐     REST API      ┌──────────────────┐     Prisma      ┌───────────────┐
│  Flutter App    │ ◄────────────────► │  Fastify + TS    │ ◄─────────────► │  PostgreSQL   │
│  (Mobile)       │    JSON over HTTPS │  (Backend API)   │                 │  (Supabase)   │
└─────────────────┘                    └──────────────────┘                 └───────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Status Engine   │
                                    │  (Pure Function) │
                                    └──────────────────┘
```

**Data Flow**: Flutter app → HTTPS REST API → Fastify routes → Controllers/Services → Prisma → PostgreSQL. Status computation runs as a pure backend function called by the water-point detail endpoint.

---

## Flutter Mobile App

### Layer Structure

```
frontend/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models (User, WaterPoint, Report, Vote)
│   ├── services/                 # API client, auth token storage
│   ├── providers/                # State management (Provider)
│   ├── screens/                  # UI screens
│   │   ├── auth/                 # Login, Register
│   │   ├── resident/             # WaterPointList, WaterPointDetail, SubmitReport, Vote
│   │   └── admin/                # WaterPointManagement, ReportModeration
│   ├── widgets/                  # Reusable UI components
│   └── utils/                    # Constants, helpers, validators
```

### Key Components

| Layer | Responsibility |
|-------|----------------|
| **Models** | Dart classes with JSON serialization; match backend DTOs |
| **Services** | HTTP client (Dio/http), token storage (flutter_secure_storage), API endpoint definitions |
| **Providers** | State management using **Provider (currently recommended; final selection during implementation)**; holds auth state, water point list, current water point detail |
| **Screens** | Page-level UI; consume providers; handle navigation |
| **Widgets** | Reusable components (status badge, queue card, report form, vote buttons) |

### Navigation
- GoRouter or Navigator 2.0 for declarative routing
- Auth guard redirects unauthenticated users to login
- Role guard redirects residents from admin screens

---

## Backend API (Fastify + TypeScript)

### Layer Structure

```
backend/
├── src/
│   ├── main.ts                   # Fastify bootstrap
│   ├── routes/                   # Route definitions (OpenAPI schemas)
│   │   ├── auth.ts               # POST /auth/register, POST /auth/login
│   │   ├── waterPoints.ts        # GET /water-points, GET /water-points/:id
│   │   ├── reports.ts            # POST /water-points/:id/reports
│   │   ├── votes.ts              # POST /reports/:id/votes, DELETE /reports/:id/votes
│   │   └── admin.ts              # POST /admin/water-points, PUT /admin/water-points/:id, DELETE /admin/water-points/:id, GET /admin/reports, DELETE /admin/reports/:id
│   ├── controllers/              # Request handling, response formatting
│   ├── services/                 # Business logic
│   │   ├── authService.ts        # Password hashing, JWT sign/verify
│   │   ├── waterPointService.ts  # Water point CRUD
│   │   ├── reportService.ts      # Report creation, retrieval
│   │   ├── voteService.ts        # Vote creation, validation
│   │   └── statusEngine.ts       # Pure status computation function
│   ├── middleware/               # Fastify hooks
│   │   ├── auth.ts               # JWT verification, attach user to request
│   │   ├── roleCheck.ts          # Admin-only route protection
│   │   └── validation.ts         # Zod schema validation
│   ├── prisma/                   # Prisma client instance
│   ├── types/                    # Shared TypeScript types
│   └── utils/                    # Helpers, error classes, logger
```

### Major Backend Layers

| Layer | Purpose |
|-------|---------|
| **Routes** | Define endpoints, HTTP methods, OpenAPI schemas, attach middleware |
| **Controllers** | Parse request, call services, format HTTP responses |
| **Services** | Pure business logic; no Fastify/HTTP dependencies; testable in isolation |
| **Middleware** | Cross-cutting concerns: auth, roles, validation, error handling |
| **Prisma** | Database access; type-safe queries; migrations |
| **Status Engine** | Pure function: `computeStatus(reports, votes) → { status, queueEstimate, confidence }` |

---

## Authentication Flow

```
1. POST /auth/register  { email, password }
   → 201 Created { user: { id, email, role } }

2. POST /auth/login  { email, password }
   → 200 OK { accessToken: "jwt...", user: { id, email, role } }

3. Client stores accessToken securely (flutter_secure_storage)

4. All subsequent requests:
   Authorization: Bearer <accessToken>

5. Backend auth middleware:
   - Verifies JWT signature (HS256)
   - Checks expiry (24 hours)
   - Attaches user { id, email, role } to request.user

6. Role middleware checks request.user.role for admin routes
```

**Token**: JWT with claims `{ sub: userId, email, role, iat, exp }`. Secret stored in env var. No refresh tokens in MVP.

---

## Authorization / Role Checking

```typescript
// Middleware: requireAuth
// Attaches request.user = { id, email, role }

// Middleware: requireAdmin
// Requires requireAuth first
// Throws 403 if request.user.role !== 'admin'

// Route usage:
fastify.get('/admin/reports', { preHandler: [requireAuth, requireAdmin] }, controller.getAllReports)
fastify.post('/water-points/:id/reports', { preHandler: [requireAuth] }, controller.createReport)
fastify.get('/water-points', { preHandler: [requireAuth] }, controller.listWaterPoints)
fastify.post('/reports/:id/votes', { preHandler: [requireAuth] }, controller.createVote)
fastify.delete('/reports/:id/votes', { preHandler: [requireAuth] }, controller.deleteVote)
fastify.post('/admin/water-points', { preHandler: [requireAuth, requireAdmin] }, controller.createWaterPoint)
fastify.put('/admin/water-points/:id', { preHandler: [requireAuth, requireAdmin] }, controller.updateWaterPoint)
fastify.delete('/admin/water-points/:id', { preHandler: [requireAuth, requireAdmin] }, controller.deleteWaterPoint)
```

**Role Matrix**:

| Endpoint | Resident | Admin |
|----------|----------|-------|
| GET /water-points | ✓ | ✓ |
| GET /water-points/:id | ✓ | ✓ |
| POST /water-points/:id/reports | ✓ | ✓ |
| POST /reports/:id/votes | ✓ | ✓ |
| DELETE /reports/:id/votes | ✓ | ✓ |
| POST /admin/water-points | ✗ | ✓ |
| PUT /admin/water-points/:id | ✗ | ✓ |
| DELETE /admin/water-points/:id | ✗ | ✓ |
| GET /admin/reports | ✗ | ✓ |
| DELETE /admin/reports/:id | ✗ | ✓ |

---

## Status Computation Engine

**Location**: `backend/src/services/statusEngine.ts`

**Signature**:
```typescript
function computeStatus(
  reports: ReportWithVotes[],
  now: Date = new Date()
): { status: 'available' | 'unavailable' | 'uncertain'; queueEstimate: number | null; confidence: number }
```

**Algorithm Steps**:

1. **Filter Window**: Keep reports where `created_at >= now - 2 hours`

2. **Recency Weight** (linear decay):
   ```
   ageMinutes = (now - report.created_at) / 60000
   recencyWeight = Math.max(0, 1 - ageMinutes / 120)
   ```

3. **Vote Factor**:
   ```
   confirms = report.votes.filter(v => v.vote_type === 'confirm').length
   contradicts = report.votes.filter(v => v.vote_type === 'contradict').length
   voteFactor = 1.0 + 0.1 * confirms - 0.15 * contradicts
   voteFactor = Math.min(1.5, Math.max(0.2, voteFactor))
   ```

4. **Effective Weight**:
   ```
   effectiveWeight = recencyWeight * voteFactor
   ```

5. **Availability Ratio**:
   ```
   availableWeight = sum of effectiveWeight where water_available = true
   totalWeight = sum of effectiveWeight for all reports
   availabilityRatio = availableWeight / totalWeight
   ```

6. **Determine Status**:
   ```
   if (availabilityRatio >= 0.65) status = 'available'
   else if (availabilityRatio <= 0.35) status = 'unavailable'
   else status = 'uncertain'
   ```

7. **Queue Estimate** (weighted median of queue_size):
   - Collect reports where `water_available = true`
   - Sort by `queue_size`
   - Accumulate `effectiveWeight` until reaching 50% of total available weight
   - Return that `queue_size` value
   - If no valid reports → `null`

8. **Confidence**:
   ```
   N = filteredReports.length
   totalEffectiveWeight = sum of effectiveWeight for all reports
   confidence = Math.round((totalEffectiveWeight / (N * 1.5)) * 100)
   confidence = Math.min(100, Math.max(0, confidence))
   ```

**Properties**:
- Pure function: no side effects, no DB calls, deterministic
- Unit-testable with fixed `now` parameter
- Runs in < 10ms for typical report volumes

---

## Request / Data Flow

### Resident Views Water Point Detail

```
1. GET /water-points/:id
   Headers: Authorization: Bearer <token>

2. Auth middleware → validates JWT, attaches user

3. Controller:
   - Calls waterPointService.getById(id)
   - Calls reportService.getRecentReports(id, 2 hours)
   - Calls voteService.getVotesForReports(reportIds)
   - Calls statusEngine.computeStatus(reportsWithVotes)
   - Returns { waterPoint, status, queueEstimate, confidence }

4. Response: 200 OK { waterPoint, status, queueEstimate, confidence }
```

### Resident Submits Report

```
1. POST /water-points/:id/reports
   Body: { water_available, queue_size, estimated_wait_minutes? }
   Headers: Authorization: Bearer <token>

2. Auth middleware → validates JWT, attaches user

3. Validation middleware → Zod schema validates body

4. Controller → reportService.createReport(userId, waterPointId, data)

5. Service:
   - Creates report record
   - Returns created report

6. Response: 201 Created { report }
```

### Resident Votes on Report

```
1. POST /reports/:id/votes
   Body: { vote_type }
   Headers: Authorization: Bearer <token>

2. Auth middleware → validates JWT

3. Validation middleware → Zod validates vote_type enum

4. Controller → voteService.createVote(userId, reportId, voteType)

5. Service:
   - Checks report exists and is < 2 hours old
   - Checks user hasn't voted on this report (unique constraint)
   - Creates vote record
   - Returns created vote

6. Response: 201 Created { vote }
```

### Admin Creates Water Point

```
1. POST /admin/water-points
   Body: { name, address, latitude, longitude, operating_hours }
   Headers: Authorization: Bearer <admin_token>

2. Auth middleware → validates JWT
3. Role middleware → requireAdmin → checks role === 'admin'

4. Validation middleware → Zod validates all fields

5. Controller → waterPointService.create(data)

6. Service → Prisma create → returns water point

7. Response: 201 Created { waterPoint }
```

---

## Major Frontend Layers Summary

| Layer | Key Files | Responsibility |
|-------|-----------|----------------|
| **Entry** | `main.dart` | App initialization, provider setup, routing |
| **Models** | `models/*.dart` | Data classes, JSON serialization, validation |
| **Services** | `services/api.dart`, `services/auth.dart` | HTTP calls, token management, endpoint URLs |
| **State** | `providers/*.dart` | Provider state classes; notify listeners on changes |
| **Screens** | `screens/**/*.dart` | Full-page UI; consume providers; handle user input |
| **Widgets** | `widgets/*.dart` | Reusable components (buttons, cards, forms, status indicators) |

---

## Major Backend Layers Summary

| Layer | Key Files | Responsibility |
|-------|-----------|----------------|
| **Bootstrap** | `main.ts` | Fastify init, plugin registration, route loading, error handler |
| **Routes** | `routes/*.ts` | Endpoint definitions, OpenAPI docs, middleware wiring |
| **Controllers** | `controllers/*.ts` | Request/response handling, HTTP status codes, serialization |
| **Services** | `services/*.ts` | Business logic, data transformation, status computation |
| **Middleware** | `middleware/*.ts` | Auth, roles, validation, logging, error formatting |
| **Data Access** | `prisma/client.ts` | PrismaClient singleton, typed queries |
| **Types** | `types/*.ts` | Shared interfaces, DTOs, enums |
| **Utils** | `utils/*.ts` | Logger, errors, constants, helpers |