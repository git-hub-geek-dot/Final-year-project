/*
  Warnings:

  - You are about to drop the column `organiser_last_read_at` on the `chat_threads` table. All the data in the column will be lost.
  - You are about to drop the column `volunteer_last_read_at` on the `chat_threads` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "chat_threads" DROP COLUMN "organiser_last_read_at",
DROP COLUMN "volunteer_last_read_at";
