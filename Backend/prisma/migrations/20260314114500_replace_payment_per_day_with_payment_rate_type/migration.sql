CREATE TYPE "PaymentRateType" AS ENUM ('per_day', 'per_hour', 'fixed');

ALTER TABLE "events"
ADD COLUMN "payment_amount" DECIMAL(10,2),
ADD COLUMN "payment_rate_type" "PaymentRateType";

UPDATE "events"
SET
  "payment_amount" = "payment_per_day",
  "payment_rate_type" = CASE
    WHEN "event_type" = 'paid' AND "payment_per_day" IS NOT NULL
      THEN 'per_day'::"PaymentRateType"
    ELSE NULL
  END;

ALTER TABLE "events"
DROP COLUMN "payment_per_day";
