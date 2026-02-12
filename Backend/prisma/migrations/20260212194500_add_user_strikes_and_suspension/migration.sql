ALTER TABLE "users"
  ADD COLUMN "suspended_until" TIMESTAMP(6),
  ADD COLUMN "suspension_reason" TEXT;

CREATE TABLE "user_strikes" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INTEGER NOT NULL,
  "admin_id" INTEGER NOT NULL,
  "reason" TEXT NOT NULL,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT NOW()
);

ALTER TABLE "user_strikes"
  ADD CONSTRAINT "user_strikes_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE;

ALTER TABLE "user_strikes"
  ADD CONSTRAINT "user_strikes_admin_id_fkey"
  FOREIGN KEY ("admin_id") REFERENCES "users"("id") ON DELETE CASCADE;

CREATE INDEX "idx_user_strikes_user_id" ON "user_strikes"("user_id");
CREATE INDEX "idx_user_strikes_admin_id" ON "user_strikes"("admin_id");
