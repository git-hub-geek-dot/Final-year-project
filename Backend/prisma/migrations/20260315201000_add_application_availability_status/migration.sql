-- Add availability status to applications
ALTER TABLE "applications"
ADD COLUMN "availability_status" VARCHAR(20) DEFAULT 'available';
