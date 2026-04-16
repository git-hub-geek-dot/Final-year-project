const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const applicationController = require("../controllers/applicationController");

/* ================= EXISTING ROUTES (UNCHANGED) ================= */

// Volunteer applies (OLD — kept to avoid breaking anything)
router.post(
  "/applications",
  authenticateToken,
  applicationController.applyToEvent
);

// Volunteer views own applications
router.get(
  "/applications/my",
  authenticateToken,
  applicationController.getMyApplications
);

/* ================= REQUIRED ROUTES (ADDED) ================= */

// 🔥 Flutter: Volunteer applies to event
router.post(
  "/events/:id/apply",
  authenticateToken,
  applicationController.applyToEvent
);

// 🔥 Flutter: Volunteer checks application status
router.get(
  "/events/:id/application-status",
  authenticateToken,
  applicationController.getApplicationStatus
);

// 🔥 Flutter: Organiser views applications for an event
router.get(
  "/events/:id/applications",
  authenticateToken,
  applicationController.getEventApplications
);

/* ================= NEW ROUTES (SAFE ADDITIONS) ================= */

// ✅ NEW: Get single application details (for ViewApplicationScreen)
router.get(
  "/applications/:id",
  authenticateToken,
  applicationController.getApplicationById
);

// ✅ NEW: Update application status (Approve / Reject)
router.put(
  "/applications/:id/status",
  authenticateToken,
  applicationController.updateApplicationStatus
);

// ✅ NEW: Toggle application shortlist (Organiser only)
router.put(
  "/applications/:id/shortlist",
  authenticateToken,
  applicationController.updateApplicationShortlist
);

// ✅ NEW: Volunteer updates compensation status
router.put(
  "/applications/:id/compensation",
  authenticateToken,
  applicationController.updateCompensationStatus
);

// ✅ NEW: Organiser marks compensation as sent
router.put(
  "/applications/:id/mark-paid",
  authenticateToken,
  applicationController.markCompensationSentByOrganiser
);

// ✅ NEW: Volunteer cancellation with strike-window policy
router.put(
  "/applications/:id/cancel",
  authenticateToken,
  applicationController.cancelMyApplication
);

// ✅ NEW: Volunteer appeal for cancellation/no-show strike
router.put(
  "/applications/:id/strike-appeal",
  authenticateToken,
  applicationController.submitStrikeAppeal
);

module.exports = router;
