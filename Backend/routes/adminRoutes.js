const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const adminOnly = require("../middleware/admin");
const adminController = require("../controllers/adminController");

// USERS
router.get(
  "/users",
  authenticateToken,
  adminOnly,
  adminController.getUsers
);

router.post(
  "/users/:id/status",
  authenticateToken,
  adminOnly,
  adminController.updateUserStatus
);

// EVENTS
router.get(
  "/events",
  authenticateToken,
  adminOnly,
  adminController.getEvents
);

// APPLICATIONS
router.get(
  "/applications",
  authenticateToken,
  adminOnly,
  adminController.getApplications
);

// STATS
router.get(
  "/stats",
  authenticateToken,
  adminOnly,
  adminController.getStats
);

router.delete(
  "/applications/:id",
  authenticateToken,
  adminOnly,
  adminController.cancelApplication
);

router.delete(
  "/events/:id",
  authenticateToken,
  adminOnly,
  adminController.deleteEvent
);

router.get(
  "/leaderboard/volunteers",
  authenticateToken,
  adminOnly,
  adminController.getVolunteerLeaderboard
);

router.get(
  "/leaderboard/organisers",
  authenticateToken,
  adminOnly,
  adminController.getOrganiserLeaderboard
);

router.post(
  "/badges/evaluate",
  authenticateToken,
  adminOnly,
  adminController.evaluateBadges
);

router.get("/badges", authenticateToken, adminOnly, adminController.getBadges);
router.post("/badges", authenticateToken, adminOnly, adminController.createBadge);

router.get(
  "/badges/users",
  authenticateToken,
  adminOnly,
  adminController.getUserBadges
);




module.exports = router;
