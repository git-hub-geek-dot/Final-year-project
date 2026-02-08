-- DropForeignKey
ALTER TABLE "chat_messages" DROP CONSTRAINT "chat_messages_sender_id_fkey";

-- DropForeignKey
ALTER TABLE "chat_threads" DROP CONSTRAINT "chat_threads_event_id_fkey";

-- DropForeignKey
ALTER TABLE "chat_threads" DROP CONSTRAINT "chat_threads_organiser_id_fkey";

-- DropForeignKey
ALTER TABLE "chat_threads" DROP CONSTRAINT "chat_threads_volunteer_id_fkey";

-- AlterTable
ALTER TABLE "chat_messages" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "chat_threads" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);
