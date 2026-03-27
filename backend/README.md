# RemitFlow Backend

Neon-backed REST API and Prisma schema for the RemitFlow mobile app.

## Endpoints
- `GET /health`
- `POST /auth/session`
- `GET /me/dashboard`
- `GET /recipients?q=...`
- `POST /transfers`

## Environment
- `DATABASE_URL`: pooled Neon connection string for runtime queries
- `DIRECT_URL`: direct Neon connection string for Prisma migrations
- `FIREBASE_PROJECT_ID`: Firebase project id for backend token verification
- `FIREBASE_CLIENT_EMAIL`: Firebase service account client email
- `FIREBASE_PRIVATE_KEY`: Firebase service account private key
- `ENABLE_DEMO_BOOTSTRAP`: optional, defaults to `true`
- `PORT`: optional, defaults to `8787`

## Local setup
1. Install dependencies.
2. Set the required environment variables.
3. Run `npm run db:generate`.
4. Run `npm run db:migrate`.
5. Run `npm run db:seed`.
6. Start the API with `npm run start` or `npm run dev`.

## Notes
- Firebase Auth is used only for identity verification. Neon/Postgres is the source of truth for app data.
- The schema uses UUIDs and decimal money fields to preserve precision.
