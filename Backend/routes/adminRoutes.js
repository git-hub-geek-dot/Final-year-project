const express = require("express");
const router = express.Router();

const authenticateToken = require("../middleware/auth");
const adminOnly = require("../middleware/admin");
const adminController = require("../controllers/adminController");


router.get("/users", adminController.getUsers);
router.get("/events", adminController.getEvents);
router.get("/applications", adminController.getApplications);
router.get("/stats", authenticateToken, adminOnly, adminController.getStats);


module.exports = router;
