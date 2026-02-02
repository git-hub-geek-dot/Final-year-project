const { Pool } = require("pg");
require("dotenv").config();

const sslModeRequired = /sslmode=require/i.test(process.env.DATABASE_URL || "");
const useSsl =
  process.env.PGSSL === "true" ||
  process.env.NODE_ENV === "production" ||
  sslModeRequired;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});

module.exports = pool;
