const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

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
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: useSsl ? { rejectUnauthorized } : undefined,
});
const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({ adapter });

async function main() {
  // ================== CATEGORIES ==================
  const categories = [
    'Education',
    'Healthcare',
    'Environment',
    'Animals',
    'Community',
    'Charity',
    'Sports & Fitness',
    'Arts & Culture',
    'Technology',
    'Skill Development',
    'Social Awareness',
    'Disaster Relief',
    'Women & Child Welfare',
    'Senior Citizen Support',
    'Cleanliness Drives',
    'Food & Nutrition',
    'Fundraising',
    'Reception & Party Management',
    'Other',
  ];

  for (const name of categories) {
    await prisma.category.upsert({
      where: { name },
      update: {},
      create: { name },
    });
  }

  // ================== ADMIN USER ==================
  const hashedPassword = await bcrypt.hash('a', 10);

  await prisma.user.upsert({
    where: { email: 'a@test.com' },
    update: {},
    create: {
      name: 'amit',
      email: 'a@test.com',
      password: hashedPassword,
      role: 'admin',
    },
  });

  console.log('✅ Admin user and categories seeded');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
