-- DropForeignKey
ALTER TABLE "user_strikes" DROP CONSTRAINT "user_strikes_admin_id_fkey";

-- DropForeignKey
ALTER TABLE "user_strikes" DROP CONSTRAINT "user_strikes_user_id_fkey";

-- AddForeignKey
ALTER TABLE "user_strikes" ADD CONSTRAINT "user_strikes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_strikes" ADD CONSTRAINT "user_strikes_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
