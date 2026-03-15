-- Add prior experience field to applications
ALTER TABLE "applications"
ADD COLUMN "prior_experience" TEXT;
