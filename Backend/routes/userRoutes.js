const express = require("express");
const {
  deleteUser,
  updateUser,
  getVolunteerDashboard,
  updateVolunteerPreferences,
} = require("../controllers/usercontroller");
const { getOrganiserPublicProfile } = require("../controllers/organiserController");

const authMiddleware = require("../middleware/auth");

const router = express.Router();

// ✅ UPDATE USER PROFILE
router.put("/users/:id", authMiddleware, updateUser);

// DELETE user by ID
router.delete("/users/:id", authMiddleware, deleteUser);

// GET organiser profile (public – for volunteers)
router.get("/organisers/:id", getOrganiserPublicProfile);

// GET volunteer dashboard (auth)
router.get("/volunteer/dashboard", authMiddleware, getVolunteerDashboard);

// UPDATE volunteer preferences (auth)
router.put("/volunteer/preferences", authMiddleware, updateVolunteerPreferences);

module.exports = router;
