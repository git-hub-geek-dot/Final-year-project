const express = require("express");
<<<<<<< HEAD
const { deleteUser } = require("../controllers/usercontroller");
const { getOrganiserPublicProfile } = require("../controllers/organiserController");
=======
const {
  deleteUser,
  getOrganiserProfile,
  updateUser,
} = require("../controllers/usercontroller");

const authMiddleware = require("../middleware/auth");
>>>>>>> 967aa70e5ed64bd61653889365519a10808ddf2e

const router = express.Router();

// ✅ UPDATE USER PROFILE
router.put("/users/:id", authMiddleware, updateUser);

// DELETE user by ID
router.delete("/users/:id", authMiddleware, deleteUser);

// GET organiser profile (public – for volunteers)
router.get("/organisers/:id", getOrganiserPublicProfile);

module.exports = router;
