const { PrismaClient } = require('../node_modules/.prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

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
    await prisma.categories.upsert({
      where: { name },
      update: {},
      create: { name },
    });
  }

  // ================== ADMIN USER ==================
  const hashedPassword = await bcrypt.hash('a', 10);

  await prisma.users.upsert({
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
