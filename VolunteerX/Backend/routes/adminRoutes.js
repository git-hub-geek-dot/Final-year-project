const express = require("express");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const adminOnly = require("../middleware/admin");
const controller = require("../controllers/adminController");

router.get("/users", authenticateToken, adminOnly, controller.getAllUsers);
router.post("/users/:id/status", authenticateToken, adminOnly, controller.updateUserStatus);

router.get("/events", authenticateToken, adminOnly, controller.getAllEvents);
router.delete("/events/:id", authenticateToken, adminOnly, controller.deleteEvent);

router.get("/applications", authenticateToken, adminOnly, controller.getAllApplications);
router.delete("/applications/:id", authenticateToken, adminOnly, controller.cancelApplication);

module.exports = router;
