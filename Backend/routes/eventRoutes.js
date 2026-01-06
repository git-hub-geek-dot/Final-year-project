const express = require("express");
const router = express.Router();

const {
  createEvent,
  getMyEvents,
  getAllEvents
} = require("../controllers/eventController");

const authMiddleware = require("../middleware/auth");

// organiser
router.post("/events", authMiddleware, createEvent);
router.get("/events/my-events", authMiddleware, getMyEvents);

// public
router.get("/events", getAllEvents);

module.exports = router;
