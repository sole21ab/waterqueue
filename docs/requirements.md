# WaterQueue Requirements

## Problem Statement

Residents in communities with shared water points cannot reliably know whether a water point is currently available or how long the queue is. This leads to wasted trips, long unexpected waits, and frustration. Existing solutions (word of mouth, social media groups) are unreliable and not real-time.

WaterQueue solves this by providing a simple mobile app where residents can:
- See current status of all water points
- Submit real-time availability and queue reports
- See computed status with confidence percentages
- Confirm or contradict recent reports from other users

Admins can manage water points and moderate reports.

## Functional Requirements

### Resident Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-01 | Register/Login | Residents register and log in with email and password |
| FR-02 | JWT Authentication | Access tokens with 24-hour expiry; stateless authentication |
| FR-03 | View Water Points | List all active water points with basic info (name, address) |
| FR-04 | View Water Point Details | See computed status (Available/Unavailable/Uncertain), queue estimate (minutes), confidence percentage |
| FR-05 | Submit Report | Report `water_available` (boolean), `queue_size` (0–50), and optional `estimated_wait_minutes` (>= 0) for a water point |
| FR-06 | Vote on Reports | Confirm or contradict reports from the last 2 hours; one vote per user per report |

### Admin Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-07 | Manage Water Points | Create, edit, and deactivate water points (name, address, latitude, longitude, operating_hours, is_active) |
| FR-08 | View All Reports | See all reports across all water points with timestamps and user info |
| FR-09 | Moderate Reports | Delete or hide inappropriate/spam reports |

### Shared Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-10 | Role-Based Access | Residents and admins have different permissions enforced by backend middleware |
| FR-11 | Status Computation | Backend computes status from reports in the last 2 hours using recency-weighted algorithm |

## Non-Functional Requirements

| ID | Requirement | Details |
|----|-------------|---------|
| NFR-01 | Authentication | JWT access tokens only; 24-hour expiry; no refresh tokens in MVP |
| NFR-02 | API Style | RESTful JSON API over HTTPS |
| NFR-03 | Validation | All inputs validated with Zod schemas on backend |
| NFR-04 | Response Time | API responses < 500ms for typical requests |
| NFR-05 | Availability | 99% uptime target for backend API |
| NFR-06 | Data Integrity | PostgreSQL constraints + Prisma validation; foreign keys, check constraints |
| NFR-07 | Test Coverage | Unit tests for status computation engine; integration tests for API endpoints |
| NFR-08 | Logging | Structured console logs for requests, errors, and auth events |
| NFR-09 | Deployment | Backend on Railway or Render; Flutter mobile build (APK/IPA) |
| NFR-10 | Security | Password hashing (bcrypt); HTTPS in production; CORS configured |

## MVP Scope

The MVP includes exactly these 9 features:

1. Registration/Login with email and password
2. JWT access-token authentication (24-hour expiry)
3. Resident water-point list
4. Water-point details with current status
5. Submit water availability and queue report
6. Confirm/contradict reports from the last 2 hours
7. Admin creates, edits, and deactivates water points
8. Admin views and moderates reports
9. Status computation: Available / Unavailable / Uncertain + queue estimate + confidence %

## Excluded Features

The following are explicitly OUT OF SCOPE for MVP and will not be implemented:

- Maps
- Push notifications
- Offline mode
- Photo uploads
- User profiles
- Reputation system
- Analytics dashboard
- Email verification
- Favorites
- Multi-language support
- Water quality information
- Comments/chat
- Real-time subscriptions (WebSockets, SSE)
- AI/ML
- IoT integration
- Payments

## Important Business Rules

### Status Computation Algorithm

**Input**: All reports for a water point from the last 2 hours, plus their votes.

**Recency Weight**:
- `recency_weight = max(0, 1 - age_minutes / 120)`

**Vote Factor**:
- `vote_factor = 1.0 + 0.1 * confirm_count - 0.15 * contradict_count`
- Clamp `vote_factor` to `[0.2, 1.5]`

**Effective Weight**:
- `effective_weight = recency_weight * vote_factor`

**Availability Ratio**:
- `available_weight` = sum of `effective_weight` for reports where `water_available = true`
- `total_weight` = sum of `effective_weight` for all reports
- `availability_ratio = available_weight / total_weight`

**Status Thresholds**:
- `availability_ratio >= 0.65` → **Available**
- `availability_ratio <= 0.35` → **Unavailable**
- Otherwise → **Uncertain**

**Queue Estimate**:
- Weighted median of `queue_size` from reports where `water_available = true`
- Weight = `effective_weight` of each report
- If no valid reports → null

**Confidence**:
- `confidence = total_effective_weight / (N * 1.5) * 100`
- `N` = number of reports in 2-hour window
- `total_effective_weight` = sum of `effective_weight` for all reports
- Rounded to nearest integer
- Minimum 0%, maximum 100%

### Data Validation Rules

- `queue_size`: Integer, 0–50 inclusive
- `estimated_wait_minutes`: Integer, ≥ 0, nullable
- `water_available`: Boolean, required
- `vote_type`: Enum ['confirm', 'contradict']
- `role`: Enum ['resident', 'admin']
- Email: Unique, valid format
- One vote per user per report (enforced by unique constraint)

### Authorization Rules

- Residents: Can read water points, submit reports, vote on recent reports
- Admins: All resident permissions + CRUD water points, view/moderate all reports
- Users cannot vote on their own reports
- Users cannot vote on reports older than 2 hours