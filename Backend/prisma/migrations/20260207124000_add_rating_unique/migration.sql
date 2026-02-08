-- CreateIndex
CREATE UNIQUE INDEX "uniq_rating_event_rater_ratee" ON "ratings"("event_id", "rater_id", "ratee_id");
