ALTER TABLE "applications"
  ADD COLUMN "volunteer_cancel_reason" TEXT,
  ADD COLUMN "cancellation_supporting_document_url" TEXT,
  ADD COLUMN "cancellation_window" VARCHAR(30),
  ADD COLUMN "warning_issued" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "strike_issued" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "volunteer_cancelled_at" TIMESTAMP(6),
  ADD COLUMN "strike_appeal_reason" TEXT,
  ADD COLUMN "strike_appeal_document_url" TEXT,
  ADD COLUMN "strike_appeal_status" VARCHAR(20) DEFAULT 'none',
  ADD COLUMN "strike_appeal_submitted_at" TIMESTAMP(6),
  ADD COLUMN "strike_appeal_reviewed_at" TIMESTAMP(6),
  ADD COLUMN "strike_appeal_review_note" TEXT;
