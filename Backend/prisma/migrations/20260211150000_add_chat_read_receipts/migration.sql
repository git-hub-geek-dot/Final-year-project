-- Add read receipt timestamps for chat threads
ALTER TABLE "chat_threads" ADD COLUMN "organiser_last_read_at" TIMESTAMP(6);
ALTER TABLE "chat_threads" ADD COLUMN "volunteer_last_read_at" TIMESTAMP(6);
