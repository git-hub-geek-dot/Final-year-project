-- Ensure enum types exist (safe for shadow DB)
DO $$ BEGIN
  CREATE TYPE "ReportTargetType" AS ENUM ('user', 'event', 'chat_message');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE "ReportStatus" AS ENUM ('pending', 'resolved', 'dismissed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Ensure reports table exists before altering (safe for shadow DB)
CREATE TABLE IF NOT EXISTS "reports" (
  id SERIAL PRIMARY KEY,
  reporter_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type "ReportTargetType" NOT NULL,
  target_id INT NOT NULL,
  reason TEXT NOT NULL,
  details TEXT,
  status "ReportStatus" NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  action_taken TEXT,
  resolved_by INT REFERENCES users(id),
  resolved_at TIMESTAMP(6),
  created_at TIMESTAMP(6) NOT NULL DEFAULT now(),
  updated_at TIMESTAMP(6) NOT NULL
);

CREATE INDEX IF NOT EXISTS "idx_reports_status" ON "reports" ("status");
CREATE INDEX IF NOT EXISTS "idx_reports_target_type" ON "reports" ("target_type");
CREATE INDEX IF NOT EXISTS "idx_reports_reporter_id" ON "reports" ("reporter_id");

-- DropForeignKey (if exists)
ALTER TABLE "reports" DROP CONSTRAINT IF EXISTS "reports_reporter_id_fkey";

-- DropForeignKey (if exists)
ALTER TABLE "reports" DROP CONSTRAINT IF EXISTS "reports_resolved_by_fkey";

-- AlterTable (ensure final types/defaults)
ALTER TABLE "reports"
  ALTER COLUMN "reason" SET DATA TYPE TEXT,
  ALTER COLUMN "action_taken" SET DATA TYPE TEXT,
  ALTER COLUMN "updated_at" DROP DEFAULT,
  ALTER COLUMN "updated_at" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_reporter_id_fkey"
  FOREIGN KEY ("reporter_id") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_resolved_by_fkey"
  FOREIGN KEY ("resolved_by") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
