const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const eventController = require("../controllers/eventController");

router.post("/events", authenticateToken, eventController.createEvent);
router.get("/events", eventController.getAllEvents);

module.exports = router;
