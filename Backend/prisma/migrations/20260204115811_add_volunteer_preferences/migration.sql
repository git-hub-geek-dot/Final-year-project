-- CreateTable
CREATE TABLE "volunteer_preferences" (
	"user_id" INTEGER NOT NULL,
	"skills" TEXT[] DEFAULT '{}'::TEXT[],
	"interests" TEXT[] DEFAULT '{}'::TEXT[],

	CONSTRAINT "volunteer_preferences_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "volunteer_preferences" ADD CONSTRAINT "volunteer_preferences_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
