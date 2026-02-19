CREATE TABLE "notifications" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INTEGER NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "data" JSONB,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "read_at" TIMESTAMP(6)
);

CREATE INDEX "idx_notifications_user_id"
  ON "notifications"("user_id");

CREATE INDEX "idx_notifications_user_created_at"
  ON "notifications"("user_id", "created_at" DESC);
