# CampaignOps Requirements

## 1. Problem

Small marketing teams manage clients, campaigns, tasks, files and approvals using disconnected spreadsheets, chat messages and email.

This causes:

- Unclear task ownership
- Missed deadlines
- Lost feedback
- Confusing approval status
- No reliable history of important changes

## 2. Proposed Solution

CampaignOps is a web application that gives marketing teams one workspace for managing clients, campaigns, tasks, files, approvals and activity history.

## 3. User Roles

### Owner

- Creates and manages the workspace
- Invites and removes members
- Changes member roles
- Has access to all workspace information

### Manager

- Creates and manages clients
- Creates campaigns
- Assigns tasks
- Reviews and approves campaign work
- Views reports and dashboard statistics

### Member

- Views assigned campaigns and tasks
- Updates assigned tasks
- Uploads files
- Adds comments
- Submits work for approval

## 4. MVP Features

- Email registration and login
- Email verification
- Protected dashboard
- Workspace creation
- Role-based authorization
- Client CRUD
- Campaign CRUD
- Task creation and assignment
- Campaign status workflow
- Approval and rejection workflow
- Comments
- Activity audit log
- Dashboard statistics
- Search and filtering

## 5. Campaign Statuses

A campaign can move through:

1. Draft
2. Active
3. In Review
4. Approved
5. Completed
6. Archived

Invalid status changes must be rejected by the backend.

## 6. Main User Flow

1. User registers and verifies their email.
2. User creates a workspace.
3. Owner adds team members.
4. Manager creates a client.
5. Manager creates a campaign for the client.
6. Manager creates and assigns tasks.
7. Member completes tasks and submits the campaign for review.
8. Manager approves it or requests changes.
9. The system records important actions in the audit log.

## 7. Security Requirements

- Users must be authenticated before accessing private pages.
- Users must only access workspaces where they are members.
- Members must not perform manager or owner actions.
- Authorization must be checked by the backend and database RLS.
- Secret keys must never be exposed in browser code.
- Inputs must be validated before database operations.
- Important status changes must be recorded.

## 8. Acceptance Criteria

- An authenticated user can create a workspace.
- A workspace owner can manage its members.
- A manager can create clients, campaigns and tasks.
- A member cannot access another workspace by changing a URL.
- A member cannot call manager-only API operations.
- Invalid campaign status transitions return an error.
- Approval actions create an audit-log entry.
- Invalid form inputs display understandable error messages.
- Core workflows have automated tests.
- Production deployment contains no hardcoded secrets.

## 9. Non-Goals for the MVP

The first version will not include:

- Payments
- Mobile applications
- AI-generated campaign briefs
- Social-media publishing
- Advanced real-time collaboration
- Google login

These may be considered after the core application is stable.

## 10. Definition of Done

A feature is complete only when:

- Acceptance criteria pass
- Authorization is tested
- Input validation is implemented
- Error states are handled
- Automated tests pass
- Code has been reviewed
- Documentation is updated
- CI checks pass