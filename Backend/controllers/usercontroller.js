import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

export const deleteUser = async (req, res) => {
  const userId = parseInt(req.params.id);

  try {
    // 1️⃣ Delete applications (volunteer)
    await prisma.application.deleteMany({
      where: { volunteerId: userId },
    });

    // 2️⃣ Delete ratings (given or received)
    await prisma.rating.deleteMany({
      where: {
        OR: [
          { raterId: userId },
          { rateeId: userId },
        ],
      },
    });

    // 3️⃣ Delete user badges
    await prisma.userBadge.deleteMany({
      where: { userId: userId },
    });

    // 4️⃣ Delete events created by organiser
    await prisma.event.deleteMany({
      where: { organiserId: userId },
    });

    // 5️⃣ FINALLY delete the user
    await prisma.user.delete({
      where: { id: userId },
    });

    return res.status(200).json({
      success: true,
      message: 'User deleted successfully',
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: 'User deletion failed',
      error: error.message,
    });
  }
};
