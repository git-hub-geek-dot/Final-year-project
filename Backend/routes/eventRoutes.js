const express = require("express");
const router = express.Router();

const {
  createEvent,
  getMyEvents,
  getAllEvents,
  updateEvent // 👈 add this
} = require("../controllers/eventController");

const authMiddleware = require("../middleware/auth");

// organiser
router.post("/events", authMiddleware, createEvent);
router.get("/events/my-events", authMiddleware, getMyEvents);

// 👇 NEW ROUTE for editing event
router.put("/events/:id", authMiddleware, updateEvent);

// public
router.get("/events", getAllEvents);

module.exports = router;
