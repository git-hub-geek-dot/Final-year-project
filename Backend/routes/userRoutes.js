const express = require("express");
const { deleteUser, getOrganiserProfile } = require("../controllers/usercontroller");

const router = express.Router();

// DELETE user by ID
router.delete("/users/:id", deleteUser);

// GET organiser profile (public)
router.get("/organisers/:id", getOrganiserProfile);

module.exports = router;
