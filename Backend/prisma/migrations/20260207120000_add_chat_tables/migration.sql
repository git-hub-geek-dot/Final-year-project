-- CreateTable
CREATE TABLE "chat_threads" (
  "id" SERIAL NOT NULL,
  "event_id" INTEGER NOT NULL,
  "organiser_id" INTEGER NOT NULL,
  "volunteer_id" INTEGER NOT NULL,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "chat_threads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_messages" (
  "id" SERIAL NOT NULL,
  "thread_id" INTEGER NOT NULL,
  "sender_id" INTEGER NOT NULL,
  "message" TEXT NOT NULL,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "uniq_chat_thread" ON "chat_threads"("event_id", "organiser_id", "volunteer_id");

-- CreateIndex
CREATE INDEX "idx_chat_thread_organiser_id" ON "chat_threads"("organiser_id");
CREATE INDEX "idx_chat_thread_volunteer_id" ON "chat_threads"("volunteer_id");
CREATE INDEX "idx_chat_message_thread_id" ON "chat_messages"("thread_id");
CREATE INDEX "idx_chat_message_sender_id" ON "chat_messages"("sender_id");

-- AddForeignKey
ALTER TABLE "chat_threads" ADD CONSTRAINT "chat_threads_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "chat_threads" ADD CONSTRAINT "chat_threads_organiser_id_fkey"
FOREIGN KEY ("organiser_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "chat_threads" ADD CONSTRAINT "chat_threads_volunteer_id_fkey"
FOREIGN KEY ("volunteer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_thread_id_fkey"
FOREIGN KEY ("thread_id") REFERENCES "chat_threads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_sender_id_fkey"
FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
