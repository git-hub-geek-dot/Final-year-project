const express = require("express");
const router = express.Router();

const {
  createEvent,
  getMyEvents,
  getAllEvents,
  getEventById,
  getVolunteerLeaderboard,
  getOrganiserLeaderboard,
  updateEvent,
  publishEvent,
} = require("../controllers/eventController");

const {
  applyToEvent,
  getApplicationStatus,
  getEventApplications,
} = require("../controllers/applicationController");

const authMiddleware = require("../middleware/auth");

// ================= ORGANISER =================
router.post("/events", authMiddleware, createEvent);
router.get("/events/my-events", authMiddleware, getMyEvents);
router.get("/events/leaderboard/organisers", authMiddleware, getOrganiserLeaderboard);
router.get("/events/leaderboard/volunteers", authMiddleware, getVolunteerLeaderboard);
router.put("/events/:id", authMiddleware, updateEvent);
router.put("/events/:id/publish", authMiddleware, publishEvent);
router.get(
  "/events/:id/applications",
  authMiddleware,
  getEventApplications
);

// ================= VOLUNTEER =================
router.post("/events/:id/apply", authMiddleware, applyToEvent);
router.get(
  "/events/:id/application-status",
  authMiddleware,
  getApplicationStatus
);

// ================= PUBLIC =================
router.get("/events/:id", getEventById);
router.get("/events", getAllEvents);

module.exports = router;
