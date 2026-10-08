# WaterQueue

## Problem Being Solved

Community water points have unpredictable availability. Residents waste time traveling to water points only to find them unavailable or with long queues. There is no reliable way to check current status before arriving.

## Project Description

WaterQueue is a Flutter mobile application that lets residents check real-time status of community water points, submit availability and queue reports, and see queue estimates with confidence percentages. Admins manage water points and moderate reports.

## Target Users

- **Residents/Community members** who use shared/community water points
- **Admins** who manage water points and moderate reports

## MVP Features (9 Features)

1. **Registration/Login** — Email and password authentication
2. **JWT Access-Token Authentication** — 24-hour expiry, stateless
3. **Resident Water-Point List** — View all active water points
4. **Water-Point Details** — Current status (Available / Unavailable / Uncertain), queue estimate, confidence percentage
5. **Submit Report** — Report water availability (boolean) and queue size (0–50)
6. **Confirm/Contradict Reports** — Vote on reports from the last 2 hours
7. **Admin Water-Point Management** — Create, edit, deactivate water points
8. **Admin Report Moderation** — View and moderate submitted reports
9. **Status Computation** — Backend algorithm computes status, queue estimate, and confidence from recent reports and votes

## Explicitly Excluded Features

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
- Real-time subscriptions
- AI/ML
- IoT
- Payments

## Technology Stack

| Layer | Technology |
|-------|------------|
| Mobile App | Flutter / Dart |
| Backend API | Node.js + Fastify + TypeScript |
| Database | PostgreSQL (Supabase free tier) |
| ORM | Prisma |
| Authentication | JWT access tokens (24-hour expiry) |
| Validation | Zod |
| Testing (Backend) | Vitest |
| Testing (Frontend) | flutter_test |
| CI/CD | GitHub Actions |
| Deployment (Backend) | Railway or Render |
| Logging | Simple console/structured logging |

## Basic Project Structure

```
WaterQueue/
├── frontend/          # Flutter mobile app
├── backend/           # Fastify + TypeScript API
├── docs/              # Project documentation
│   ├── requirements.md
│   ├── architecture.md
│   └── database.md
├── .gitignore
└── README.md
```

## Development Status

**Week 1**: Initial project documentation only. No implementation code created yet.