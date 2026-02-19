CREATE TABLE "chat_thread_reads" (
  "thread_id" INTEGER NOT NULL,
  "user_id" INTEGER NOT NULL,
  "last_read_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  CONSTRAINT "chat_thread_reads_pkey" PRIMARY KEY ("thread_id", "user_id"),
  CONSTRAINT "chat_thread_reads_thread_id_fkey"
    FOREIGN KEY ("thread_id") REFERENCES "chat_threads"("id")
    ON DELETE CASCADE,
  CONSTRAINT "chat_thread_reads_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE
);

CREATE INDEX "idx_chat_thread_reads_user_id"
  ON "chat_thread_reads"("user_id");
