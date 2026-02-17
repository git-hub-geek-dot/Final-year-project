-- Normalize legacy application status values to the canonical "approved".
UPDATE "applications"
SET "status" = 'approved'
WHERE LOWER(COALESCE("status", '')) = 'accepted';
