const { Pool } = require("pg");
require("dotenv").config();

const useSsl = process.env.PGSSL === "true" || process.env.NODE_ENV === "production";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});

module.exports = pool;
