ALTER TABLE "users"
ADD COLUMN "firebase_uid" TEXT,
ADD COLUMN "display_name" TEXT,
ADD COLUMN "photo_url" TEXT,
ADD COLUMN "phone_number" TEXT,
ADD COLUMN "available_balance_usd" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN "lifetime_savings_usd" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "users"
ALTER COLUMN "country" SET DEFAULT 'US';

CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");

CREATE TABLE "exchange_rates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "base_currency" VARCHAR(3) NOT NULL,
    "quote_currency" VARCHAR(3) NOT NULL,
    "rate" DECIMAL(12,4) NOT NULL,
    "cheaper_percentage" DECIMAL(5,2) NOT NULL,
    "as_of" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "exchange_rates_base_currency_quote_currency_key" ON "exchange_rates"("base_currency", "quote_currency");
