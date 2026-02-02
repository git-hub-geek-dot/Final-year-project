const express = require("express");
const { deleteUser } = require("../controllers/usercontroller");
const { getOrganiserPublicProfile } = require("../controllers/organiserController");

const router = express.Router();

// DELETE user by ID
router.delete("/users/:id", deleteUser);

// GET organiser profile (public – for volunteers)
router.get("/organisers/:id", getOrganiserPublicProfile);

module.exports = router;
