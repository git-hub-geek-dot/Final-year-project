const express = require("express");
const router = express.Router();

const adminController = require("../controllers/adminController");

router.get("/users", adminController.getUsers);
router.get("/events", adminController.getEvents);

module.exports = router;
