-- Create enum types for reports
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

-- Create reports table
CREATE TABLE IF NOT EXISTS "reports" (
  id SERIAL PRIMARY KEY,
  reporter_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type "ReportTargetType" NOT NULL,
  target_id INT NOT NULL,
  reason VARCHAR(255) NOT NULL,
  details TEXT,
  status "ReportStatus" NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  action_taken VARCHAR(50),
  resolved_by INT REFERENCES users(id),
  resolved_at TIMESTAMP(6),
  created_at TIMESTAMP(6) NOT NULL DEFAULT now(),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "idx_reports_status" ON "reports" ("status");
CREATE INDEX IF NOT EXISTS "idx_reports_target_type" ON "reports" ("target_type");
CREATE INDEX IF NOT EXISTS "idx_reports_reporter_id" ON "reports" ("reporter_id");
