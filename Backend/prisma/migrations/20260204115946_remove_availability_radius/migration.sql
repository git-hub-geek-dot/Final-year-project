-- DropForeignKey
ALTER TABLE "volunteer_preferences" DROP CONSTRAINT IF EXISTS "volunteer_preferences_user_id_fkey";

-- AlterTable
ALTER TABLE "volunteer_preferences" DROP COLUMN IF EXISTS "availability";
ALTER TABLE "volunteer_preferences" DROP COLUMN IF EXISTS "radius_km";

-- AddForeignKey
ALTER TABLE "volunteer_preferences" ADD CONSTRAINT "volunteer_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
