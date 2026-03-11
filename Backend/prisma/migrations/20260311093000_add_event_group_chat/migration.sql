CREATE TABLE "event_group_messages" (
  "id" SERIAL PRIMARY KEY,
  "event_id" INTEGER NOT NULL,
  "sender_id" INTEGER NOT NULL,
  "message" TEXT NOT NULL,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT NOW()
);

ALTER TABLE "event_group_messages"
  ADD CONSTRAINT "event_group_messages_event_id_fkey"
  FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_group_messages"
  ADD CONSTRAINT "event_group_messages_sender_id_fkey"
  FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "idx_event_group_messages_event_id" ON "event_group_messages"("event_id");
CREATE INDEX "idx_event_group_messages_created_at" ON "event_group_messages"("created_at");
