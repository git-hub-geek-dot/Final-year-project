const express = require("express");
const router = express.Router();

const {
  createEvent,
  getMyEvents,
  getAllEvents
} = require("../controllers/eventController");

const {
  applyToEvent,
  getApplicationStatus,
  getMyApplications
} = require("../controllers/applicationController");

const authMiddleware = require("../middleware/auth");

// organiser
router.post("/events", authMiddleware, createEvent);
router.get("/events/my-events", authMiddleware, getMyEvents);

// volunteer
router.post("/events/:id/apply", authMiddleware, applyToEvent);
router.get("/events/:id/application-status", authMiddleware, getApplicationStatus);
router.get("/my-applications", authMiddleware, getMyApplications);

// public
router.get("/events", getAllEvents);

module.exports = router;
