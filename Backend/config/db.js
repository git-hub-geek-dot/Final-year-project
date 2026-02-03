const { Pool } = require("pg");
require("dotenv").config();

const sslModeRequired = /sslmode=require|sslmode=verify-ca|sslmode=verify-full/i.test(
  process.env.DATABASE_URL || ""
);
const pgSslEnv = (process.env.PGSSL || "").toLowerCase();
const pgSslMode = (process.env.PGSSLMODE || "").toLowerCase();
const useSsl =
  pgSslEnv === "true" ||
  pgSslEnv === "1" ||
  pgSslEnv === "yes" ||
  pgSslMode === "require" ||
  pgSslMode === "verify-ca" ||
  pgSslMode === "verify-full" ||
  process.env.NODE_ENV === "production" ||
  sslModeRequired;

const rejectUnauthorized = ["true", "1", "yes"].includes(
  (process.env.PGSSL_REJECT_UNAUTHORIZED || "").toLowerCase()
);

if ((process.env.PGSSL_DEBUG || "").toLowerCase() === "true") {
  console.log("[PGSSL] useSsl:", useSsl);
  console.log("[PGSSL] rejectUnauthorized:", rejectUnauthorized);
  console.log("[PGSSL] PGSSL:", pgSslEnv || "(empty)");
  console.log("[PGSSL] PGSSLMODE:", pgSslMode || "(empty)");
  console.log("[PGSSL] sslmode in URL:", sslModeRequired);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: useSsl ? { rejectUnauthorized } : undefined,
});

module.exports = pool;
