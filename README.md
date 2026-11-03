# WaterQueue

**A Community-Based Water Availability and Queue Reporting System**

WaterQueue is a mobile application designed to help people find out whether community water points are available before walking to them. Users can check the latest reported water status, view estimated queue sizes, and submit reports to help others make informed decisions.

## 1. Problem Statement

Access to water is an everyday challenge in communities where water availability can be inconsistent. People may not know whether a nearby water point currently has water or how long the queue might be.

This problem is also experienced on university campuses. At times, water is unavailable in one block, so students have to walk to other blocks to check for available water. Sometimes, after spending time and energy walking to another block, they discover that water is unavailable there too. These unnecessary trips waste students' time and energy, particularly when they need water for their daily activities.

Without a convenient way to check current water conditions, people must rely on physical visits or information from others that may no longer be accurate.

WaterQueue addresses this information gap by providing a shared platform where users can check recently reported water availability and estimated queue sizes before deciding where to go.

## 2. Project Objectives

The main objectives of WaterQueue are to:

- Help users check reported water availability before visiting a water point.
- Provide estimated queue sizes to help users compare available options.
- Allow community members to submit water availability and queue reports.
- Combine recent reports to estimate the current status of a water point.
- Communicate uncertainty when reports do not provide a sufficiently clear picture.
- Provide administrative tools for managing water points and moderating reports.

## 3. Target Users

### Residents and Students

Residents and students can:

- View available water points.
- Check the latest estimated status of a water point.
- View estimated queue sizes and confidence information.
- Submit reports about water availability and queue sizes.
- Vote on recent reports to help indicate whether the information remains accurate.

### Administrators

Administrators can:

- Add new water points.
- Update existing water point information.
- Deactivate water points that should no longer appear as active.
- Review and moderate community reports.
- Manage water point information through the administrative interface.

## 4. Main Features

### Water Point Listing

Users can view registered water points and their current estimated status.

### Water Point Details

Users can view information about a specific water point, including its location details, operating hours, reported status, and available queue estimates.

### Community Reporting

Authenticated users can report:

- Whether water is available.
- The estimated queue size, from 0 to 50.

### Report Voting

Users can vote on recent reports to indicate whether the reported information is still accurate.

### Water Status Estimation

The system uses recent reports and their weights to estimate whether a water point is available, unavailable, or uncertain.

### Confidence Information

The system provides a confidence estimate to help users understand how strongly the available reports support the current status.

### Administrative Management

Administrators can create, update, and deactivate water points and moderate community reports.

### Authentication and Authorization

Users sign in to access protected features. Administrative operations are restricted by the backend to accounts with the administrator role.

## 5. How WaterQueue Works

1. Users open the application and view registered water points.
2. The system calculates an estimated status using recent community reports.
3. Users check the reported water availability and estimated queue size.
4. Authenticated users submit new reports based on their observations.
5. Users can vote on recent reports.
6. The system uses the available reports and votes to update its estimates.
7. Users can use this information to make a more informed decision about which water point to visit.

**Important:** WaterQueue provides estimates based on community reports. It does not directly measure water availability, and the displayed information may become outdated as conditions change.

## 6. Water Status Estimation

WaterQueue uses a rule-based approach to estimate water availability from recent reports.

### Report Recency

Reports from the most recent two hours are considered. Newer reports receive more weight than older reports.

### Voting

Votes influence the weight assigned to reports, helping the system account for community feedback.

### Status Classification

The system calculates a weighted availability score and classifies the estimated status as follows:

- **Available:** Score is greater than or equal to 0.65.
- **Unavailable:** Score is less than or equal to 0.35.
- **Uncertain:** Score is greater than 0.35 and less than 0.65.

### Queue Estimation

The system uses a weighted median of reported queue sizes to estimate the queue.

### Confidence

The system calculates a confidence estimate based on the available report weights. This helps communicate how much supporting information is available.

These calculations provide estimates rather than guarantees of actual water conditions.

## 7. Technology Stack

### Mobile Application

- Flutter
- Dart

### Backend

- Node.js
- Fastify
- TypeScript
- REST API

### Database

- PostgreSQL
- Supabase
- Prisma ORM

### Authentication and Validation

- JSON Web Tokens (JWT)
- bcrypt for password hashing
- Zod for request validation

### Testing

- Vitest for backend tests
- Flutter test framework for mobile application tests

### Version Control

- Git
- GitHub

## 8. System Architecture

WaterQueue follows a client-server architecture.

**Flutter Mobile Application → Fastify REST API → PostgreSQL Database**

- **Mobile application:** Displays water point information and provides interfaces for residents and administrators.
- **Backend API:** Handles authentication, authorization, validation, water point management, reports, voting, and status estimation.
- **Database:** Stores application data, including users, water points, reports, and votes.
- **Prisma ORM:** Provides the interface between the backend application and the PostgreSQL database.

The backend enforces access permissions for protected operations. Hiding administrative controls in the mobile application is not a substitute for backend authorization.

## 9. Project Scope

### Included in the MVP

- User authentication.
- Resident and administrator roles.
- Water point listing and details.
- Water availability and queue-size reporting.
- Voting on recent reports.
- Rule-based water status estimation.
- Queue-size estimation and confidence information.
- Administrative water point management.
- Report moderation.
- Backend and mobile application tests.

### Not Included in the Current MVP

- Push notifications.
- Offline functionality.
- Photo uploads.
- User reputation and reward systems.
- Advanced analytics.
- Real-time IoT water sensors.
- Machine learning-based predictions.
- Payments.
- In-app chat.
- Water quality monitoring.

Keeping these features outside the initial scope allows the project to focus on its primary goal: making community-reported water availability information easier to access.

## 10. Prerequisites

To run the project locally, you need:

- Git
- Node.js and npm
- Flutter SDK and Dart
- A configured Flutter development device or browser
- A PostgreSQL database, such as a configured Supabase project
- The project environment variables configured for your local setup

## 11. Getting Started

### Step 1: Clone the Repository

```bash
git clone https://github.com/sole21ab/waterqueue.git
cd waterqueue
```

### Step 2: Configure the Backend

Open a terminal in the backend directory:

```bash
cd backend
npm install
```

Create a local `.env` file using `.env.example` as a reference. Configure the required database connection, authentication settings, and other environment variables.

**Do not commit `.env` or publish database credentials, passwords, or authentication secrets.**

### Step 3: Set Up the Database

Run the database commands specified by the project's Prisma configuration and development workflow.

To check the database connection, run:

```bash
npm run db:check
```

If you need to initialize the development administrator account and demo water points, use the seed command only after confirming that your environment variables point to the intended development database:

```bash
npm run db:seed
```

The seed script can update the configured administrator account and predefined demo water points. Do not run it against a database containing data you need to preserve without reviewing its behavior first.

### Step 4: Start the Backend

From the `backend` directory, run:

```bash
npm run dev
```

Keep this terminal open while using the application.

### Step 5: Run the Mobile Application

Open a second terminal and navigate to the mobile directory:

```bash
cd mobile
flutter pub get
```

Check the available Flutter devices:

```bash
flutter devices
```

For a browser-based development run, use:

```bash
flutter run -d chrome
```

Ensure the application's API base URL points to the running backend and that the browser can reach the API. If the backend is not running or the API URL is incorrect, the application may be unable to retrieve water point information.

## 12. Testing

### Backend Tests

From the `backend` directory:

```bash
npm test
```

Check TypeScript types:

```bash
npm run typecheck
```

Build the backend:

```bash
npm run build
```

Check the database connection:

```bash
npm run db:check
```

### Mobile Application Tests

From the `mobile` directory:

```bash
flutter test
```

Analyze the Flutter code:

```bash
flutter analyze
```

## 13. Security Considerations

- Passwords are hashed using bcrypt.
- JWTs are used to authenticate protected requests.
- Backend authorization restricts administrative operations to administrator accounts.
- Request data is validated before being processed.
- Environment variables are used for sensitive configuration.
- The application should not be treated as an authoritative source of water availability because its estimates depend on community reports.

## 14. Current Limitations

- Water status depends on users submitting reasonably accurate and recent reports.
- Reported conditions may change after a user checks the application.
- Queue sizes are estimates and may differ from actual queue lengths.
- WaterQueue does not directly sense or verify whether water is physically flowing.
- Access to the backend and database requires a working network connection.
- The current MVP focuses on core reporting and management rather than advanced notifications or offline support.

## 15. Future Improvements

Possible future improvements include:

- Notifications when water availability changes.
- Better support for unreliable internet connections.
- Map-based discovery of nearby water points.
- Additional tools for identifying outdated or conflicting reports.
- Expanded deployment and monitoring.
- More extensive user feedback and usability testing.

These are possible future improvements and are not claims about features already implemented.

## 16. Repository Structure

```text
waterqueue/
├── backend/
│   ├── prisma/
│   ├── src/
│   ├── tests/
│   ├── .env.example
│   └── package.json
├── mobile/
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
├── docs/
├── .gitignore
└── README.md
```

The exact contents may change as development continues.

## 17. Project Purpose

WaterQueue aims to reduce unnecessary trips to water points by helping students and community members check recent water availability reports and estimated queues before deciding where to go.

By making community observations easier to share, the project seeks to save time and energy and support better-informed decisions about accessing water.

## 18. Project Developer and Role

Developer: Soleyana Abera Derara

ID: CTC-3962-26

Role: Solo Developer

Responsibilities:

Project planning and requirements analysis.

System architecture and database design.

Flutter mobile application development.

Backend API development using Fastify and TypeScript.

Database integration using PostgreSQL, Supabase, and Prisma ORM.

Authentication, authorization, and input validation.

Water availability and queue estimation logic.

Administrator interface and water point management.

Testing, debugging, documentation, and version control using Git and GitHub.

---

**Repository:** [https://github.com/sole21ab/waterqueue]
