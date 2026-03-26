# RemitFlow Backend Database

Prisma setup for the RemitFlow Postgres database.

## Tables
- `users`
- `transactions`

## Local setup
1. Set `DATABASE_URL` to your runtime Neon connection string.
2. Set `DIRECT_URL` to your direct, non-pooled Neon connection string.
3. Install dependencies.
4. Run `npm run db:generate`.
5. Run `npm run db:migrate` to create the initial schema.

## Notes
- The schema uses Postgres UUIDs and `Decimal` fields to preserve money precision.
- `bank_details` is stored as encrypted text, matching the PRD and data model.
