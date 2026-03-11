const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const adminOnly = require("../middleware/admin");
const adminController = require("../controllers/adminController");
// note: DB access delegated to adminController (uses pool)


// ================= USERS =================
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

router.post(
  "/users/:id/note",
  authenticateToken,
  adminOnly,
  adminController.updateUserNote
);

router.post(
  "/users/:id/strikes",
  authenticateToken,
  adminOnly,
  adminController.addUserStrike
);

router.post(
  "/users/:id/strikes/reset",
  authenticateToken,
  adminOnly,
  adminController.resetUserStrikes
);

router.post(
  "/users/:id/suspend",
  authenticateToken,
  adminOnly,
  adminController.suspendUser
);

router.post(
  "/users/:id/unsuspend",
  authenticateToken,
  adminOnly,
  adminController.unsuspendUser
);

// ================= EVENTS =================
router.get(
  "/events",
  authenticateToken,
  adminOnly,
  adminController.getEvents
);

// ================= APPLICATIONS =================
router.get(
  "/applications",
  authenticateToken,
  adminOnly,
  adminController.getApplications
);

router.delete(
  "/applications/:id",
  authenticateToken,
  adminOnly,
  adminController.cancelApplication
);

router.put(
  "/applications/:id/strike-appeal/review",
  authenticateToken,
  adminOnly,
  adminController.reviewStrikeAppeal
);

// ================= STATS =================
router.get(
  "/stats",
  authenticateToken,
  adminOnly,
  adminController.getStats
);

router.get(
  "/stats/timeseries",
  authenticateToken,
  adminOnly,
  adminController.getStatsTimeseries
);

// ================= EVENTS DELETE =================
router.delete(
  "/events/:id",
  authenticateToken,
  adminOnly,
  adminController.deleteEvent
);

router.delete(
  "/events/:id/hard",
  authenticateToken,
  adminOnly,
  adminController.hardDeleteEvent
);

// ================= LEADERBOARD =================
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

// ================= BADGES =================
router.post(
  "/badges/evaluate",
  authenticateToken,
  adminOnly,
  adminController.evaluateBadges
);

router.get(
  "/badges",
  authenticateToken,
  adminOnly,
  adminController.getBadges
);

router.post(
  "/badges",
  authenticateToken,
  adminOnly,
  adminController.createBadge
);

router.get(
  "/badges/users",
  authenticateToken,
  adminOnly,
  adminController.getUserBadges
);

router.delete(
  "/badges/:id",
  authenticateToken,
  adminOnly,
  adminController.deleteBadge
);

// =================================================
// ========== VERIFICATION (NEW - SAFE) =============
// =================================================

// 🔍 Get all verification requests
router.get(
  "/verification-requests",
  authenticateToken,
  adminOnly,
  adminController.getVerificationRequests
);

// ✅ Approve verification
router.post(
  "/verification/approve",
  authenticateToken,
  adminOnly,
  adminController.approveVerification
);

// ❌ Reject verification
router.post(
  "/verification/reject",
  authenticateToken,
  adminOnly,
  adminController.rejectVerification
);

// =================================================
// ========== BROADCAST NOTIFICATIONS ==============
// =================================================

// Send broadcast notification
router.post(
  "/notifications/broadcast",
  authenticateToken,
  adminOnly,
  adminController.sendBroadcastNotification
);

// Send targeted notification to users
router.post(
  "/notifications/users",
  authenticateToken,
  adminOnly,
  adminController.sendTargetedNotification
);

// Send notification to event users
router.post(
  "/notifications/event",
  authenticateToken,
  adminOnly,
  adminController.sendEventNotification
);

// =================================================
// ================= REPORTS =======================
// =================================================

// Get reports
router.get(
  "/reports",
  authenticateToken,
  adminOnly,
  adminController.getReports
);

// Resolve report
router.post(
  "/reports/:id/resolve",
  authenticateToken,
  adminOnly,
  adminController.resolveReport
);

// Dismiss report
router.post(
  "/reports/:id/dismiss",
  authenticateToken,
  adminOnly,
  adminController.dismissReport
);

module.exports = router;
