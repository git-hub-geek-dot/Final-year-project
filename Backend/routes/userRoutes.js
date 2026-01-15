const express = require("express");
const { deleteUser } = require("../controllers/usercontroller");

const router = express.Router();

// DELETE user by ID
router.delete("/users/:id", deleteUser);

module.exports = router;
