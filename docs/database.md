# WaterQueue Database Schema

## Overview

PostgreSQL database managed via Prisma ORM. Four core tables with explicit relationships, constraints, and indexes designed for the status computation algorithm.

---

## Tables

### 1. users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('resident', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Purpose**: Authentication and authorization. Every report and vote links to a user.

**Columns**:
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | Unique identifier |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Login identifier |
| password_hash | VARCHAR(255) | NOT NULL | Bcrypt hash |
| role | VARCHAR(20) | NOT NULL, CHECK | 'resident' or 'admin' |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | Account creation timestamp |

**Indexes**:
- Primary key on `id`
- Unique index on `email` (enforced by UNIQUE constraint)

**Why this table exists**: Required for JWT authentication, role-based access control, and audit trail of who submitted reports/votes.

---

### 2. water_points

```sql
CREATE TABLE water_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address VARCHAR(500) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    operating_hours VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Purpose**: Represents a physical community water point that residents can report on.

**Columns**:
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | Unique identifier |
| name | VARCHAR(255) | NOT NULL | Display name (e.g., "Main Street Well") |
| address | VARCHAR(500) | NOT NULL | Human-readable address |
| latitude | DECIMAL(10,8) | NOT NULL | GPS latitude for location |
| longitude | DECIMAL(11,8) | NOT NULL | GPS longitude for location |
| operating_hours | VARCHAR(100) | NOT NULL | e.g., "06:00-22:00" or "24/7" |
| is_active | BOOLEAN | NOT NULL, default true | Admin can deactivate without deleting |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | Creation timestamp |

**Indexes**:
- Primary key on `id`
- Index on `is_active` (for filtering active water points in list view)

**Why this table exists**: Core entity. Residents browse water points; admins manage them; reports and votes reference water points.

---

### 3. reports

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    water_point_id UUID NOT NULL REFERENCES water_points(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    water_available BOOLEAN NOT NULL,
    queue_size INT NOT NULL CHECK (queue_size >= 0 AND queue_size <= 50),
    estimated_wait_minutes INT NULL CHECK (estimated_wait_minutes >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Purpose**: A resident's observation of water availability and queue at a specific time.

**Columns**:
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | Unique identifier |
| water_point_id | UUID | NOT NULL, FK → water_points(id), CASCADE | Which water point |
| user_id | UUID | NOT NULL, FK → users(id), CASCADE | Who submitted |
| water_available | BOOLEAN | NOT NULL | True = water flowing, False = no water |
| queue_size | INT | NOT NULL, CHECK 0-50 | Number of people waiting |
| estimated_wait_minutes | INT | NULL, CHECK >= 0 | Optional wait estimate in minutes |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | When report was submitted |

**Indexes**:
- Primary key on `id`
- Composite index on `(water_point_id, created_at DESC)` (for fetching recent reports for status computation)
- Index on `user_id` (for user's report history)

**Constraints**:
- Foreign key to `water_points` with CASCADE delete (water point deleted → reports deleted)
- Foreign key to `users` with CASCADE delete (user deleted → reports deleted)
- Check constraint: `queue_size` between 0 and 50 inclusive
- Check constraint: `estimated_wait_minutes` >= 0 when not null

**Why this table exists**: Primary data source for status computation. Each report is a weighted input into the algorithm.

---

### 4. votes

```sql
CREATE TABLE votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vote_type VARCHAR(20) NOT NULL CHECK (vote_type IN ('confirm', 'contradict')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (report_id, user_id)
);
```

**Purpose**: Residents confirm or contradict other users' reports within the 2-hour window.

**Columns**:
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | Unique identifier |
| report_id | UUID | NOT NULL, FK → reports(id), CASCADE | Which report being voted on |
| user_id | UUID | NOT NULL, FK → users(id), CASCADE | Who voted |
| vote_type | VARCHAR(20) | NOT NULL, CHECK | 'confirm' or 'contradict' |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | When vote was cast |

**Indexes**:
- Primary key on `id`
- Unique index on `(report_id, user_id)` (enforces one vote per user per report)
- Index on `report_id` (for fetching all votes for a report)

**Constraints**:
- Foreign key to `reports` with CASCADE delete (report deleted → votes deleted)
- Foreign key to `users` with CASCADE delete (user deleted → votes deleted)
- Check constraint: `vote_type` must be 'confirm' or 'contradict'
- Unique constraint on `(report_id, user_id)` prevents duplicate votes

**Why this table exists**: Community verification mechanism. Votes adjust report weights in the status algorithm, reducing impact of stale or incorrect reports.

---

## Relationships

```
users (1) ─────< (N) reports
    │                   │
    │                   │
    └─────< (N) votes ──┘
          │
          │
water_points (1) ─────< (N) reports ─────< (N) votes
```

**Description**:
- One user can submit many reports
- One user can cast many votes (but only one per report)
- One water point can have many reports
- One report can have many votes
- Cascade deletes ensure referential integrity when parent records are removed

---

## Important Constraints Summary

| Constraint | Table | Purpose |
|------------|-------|---------|
| PK | All tables | Unique row identification |
| UNIQUE (email) | users | Prevent duplicate accounts |
| UNIQUE (report_id, user_id) | votes | One vote per user per report |
| FK (water_point_id) | reports → water_points | Referential integrity |
| FK (user_id) | reports → users | Referential integrity |
| FK (report_id) | votes → reports | Referential integrity |
| FK (user_id) | votes → users | Referential integrity |
| CHECK (role IN...) | users | Valid roles only |
| CHECK (vote_type IN...) | votes | Valid vote types only |
| CHECK (queue_size 0-50) | reports | Reasonable queue bounds |
| CHECK (estimated_wait_minutes >= 0) | reports | Non-negative wait time |
| CASCADE DELETE | All FKs | Clean orphan removal |

---

## Indexes Summary

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| PK | users | id | Primary key |
| UQ | users | email | Fast login lookup, uniqueness |
| PK | water_points | id | Primary key |
| IDX | water_points | is_active | Filter active water points (list view) |
| PK | reports | id | Primary key |
| IDX | reports | (water_point_id, created_at DESC) | **Critical**: Fetch recent reports for status computation |
| IDX | reports | user_id | User's report history |
| PK | votes | id | Primary key |
| UQ | votes | (report_id, user_id) | Enforce one vote per user per report |
| IDX | votes | report_id | Fetch all votes for a report |

---

## Why Each Table Exists

| Table | Reason |
|-------|--------|
| **users** | Authentication (email/password + JWT), authorization (role), audit trail for reports and votes |
| **water_points** | Core domain entity; represents physical water sources; managed by admins; queried by residents |
| **reports** | Primary input to status algorithm; captures availability + queue at a point in time; time-series data |
| **votes** | Community verification layer; adjusts report weights in algorithm; prevents single bad reports from skewing status |

---

## Prisma Schema Reference

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String    @id @default(uuid())
  email         String    @unique
  passwordHash  String    @map("password_hash")
  role          Role      @default(resident)
  createdAt     DateTime  @default(now()) @map("created_at")
  reports       Report[]
  votes         Vote[]

  @@map("users")
}

model WaterPoint {
  id              String    @id @default(uuid())
  name            String
  address         String
  latitude        Decimal   @db.Decimal(10, 8)
  longitude       Decimal   @db.Decimal(11, 8)
  operatingHours  String    @map("operating_hours")
  isActive        Boolean   @default(true) @map("is_active")
  createdAt       DateTime  @default(now()) @map("created_at")
  reports         Report[]

  @@index([isActive])
  @@map("water_points")
}

model Report {
  id                   String    @id @default(uuid())
  waterPointId         String    @map("water_point_id")
  userId               String    @map("user_id")
  waterAvailable       Boolean   @map("water_available")
  queueSize            Int       @map("queue_size")
  estimatedWaitMinutes Int?      @map("estimated_wait_minutes")
  createdAt            DateTime  @default(now()) @map("created_at")
  waterPoint           WaterPoint @relation(fields: [waterPointId], references: [id], onDelete: Cascade)
  user                 User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  votes                Vote[]

  @@index([waterPointId, createdAt(sort: Desc)])
  @@index([userId])
  @@map("reports")
}

model Vote {
  id        String   @id @default(uuid())
  reportId  String   @map("report_id")
  userId    String   @map("user_id")
  voteType  VoteType @map("vote_type")
  createdAt DateTime @default(now()) @map("created_at")
  report    Report   @relation(fields: [reportId], references: [id], onDelete: Cascade)
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([reportId, userId])
  @@index([reportId])
  @@map("votes")
}

enum Role {
  resident
  admin
}

enum VoteType {
  confirm
  contradict
}
```

---

## Migration Notes

- Migrations are created via `prisma migrate dev` and committed to version control
- Initial migration creates all four tables with constraints and indexes
- Subsequent schema changes generate new migration files
- Never edit migration files after they are applied to production