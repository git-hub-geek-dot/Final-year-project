const pool = require("../config/db");

// ================= GET ALL USERS =================
const getUsers = async (req, res) => {
  try {
    const users = await pool.query(
      "SELECT id, name, email, role FROM users ORDER BY id DESC"
    );
    res.json(users.rows);
  } catch (err) {
    console.error("GET USERS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

// ================= GET ALL EVENTS =================
const getEvents = async (req, res) => {
  try {
    const events = await pool.query(
      "SELECT * FROM events ORDER BY id DESC"
    );
    res.json(events.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

module.exports = {
  getUsers,
  getEvents,
};
