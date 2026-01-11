import { defineConfig } from "prisma/config";
import dotenv from "dotenv";

dotenv.config();

export default defineConfig({
  migrations: {
    seed: "node prisma/seed.js",
  },
  datasource: {
    url: process.env.DATABASE_URL!,
  },
});
