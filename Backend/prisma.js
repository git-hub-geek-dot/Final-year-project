const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const sslModeRequired = /sslmode=require/i.test(process.env.DATABASE_URL || "");
const useSsl =
	process.env.PGSSL === "true" ||
	process.env.NODE_ENV === "production" ||
	sslModeRequired;
const pool = new Pool({
	connectionString: process.env.DATABASE_URL,
	ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});
const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({ adapter });

module.exports = prisma;
