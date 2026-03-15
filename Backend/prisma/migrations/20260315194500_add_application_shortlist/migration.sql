-- Add shortlist flag to applications
ALTER TABLE "applications"
ADD COLUMN "is_shortlisted" BOOLEAN NOT NULL DEFAULT false;
