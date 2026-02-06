-- CreateEnum
CREATE TYPE "OtpChannel" AS ENUM ('email', 'phone');

-- CreateTable
CREATE TABLE "otp_verifications" (
    "id" SERIAL NOT NULL,
    "identifier" TEXT NOT NULL,
    "channel" "OtpChannel" NOT NULL,
    "codeHash" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "verified_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_verifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_otp_identifier_channel" ON "otp_verifications"("identifier", "channel");
