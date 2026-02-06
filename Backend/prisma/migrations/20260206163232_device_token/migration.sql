/*
  Warnings:

  - You are about to alter the column `platform` on the `device_tokens` table. The data in that column could be lost. The data in that column will be cast from `Text` to `VarChar(20)`.

*/
-- AlterTable
ALTER TABLE "device_tokens" ALTER COLUMN "platform" SET DATA TYPE VARCHAR(20),
ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);
