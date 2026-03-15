ALTER TABLE "applications"
ADD COLUMN IF NOT EXISTS "attendance_status" VARCHAR(20) NOT NULL DEFAULT 'unmarked',
ADD COLUMN IF NOT EXISTS "attendance_marked_at" TIMESTAMP(6);
