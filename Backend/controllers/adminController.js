const pool = require("../config/db");

// ================= GET ALL USERS =================
const getUsers = async (req, res) => {
  try {
    const users = await pool.query(
      "SELECT id, name, email, role, status, created_at FROM users ORDER BY id DESC"
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
      `SELECT e.*, u.name AS organizer_name
       FROM events e
       JOIN users u ON e.organizer_id = u.id
       ORDER BY e.id DESC`
    );
    res.json(events.rows);
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

// ================= GET ALL APPLICATIONS =================
const getApplications = async (req, res) => {
  try {
    const apps = await pool.query(
      `SELECT 
         a.id,
         a.status,
         u.name AS volunteer_name,
         u.email AS volunteer_email,
         e.title AS event_title
       FROM applications a
       JOIN users u ON a.volunteer_id = u.id
       JOIN events e ON a.event_id = e.id
       ORDER BY a.applied_at DESC`
    );

    res.json(apps.rows);
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

const getStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COUNT(*) FROM events) AS total_events,
        (SELECT COUNT(*) FROM events WHERE status = 'active') AS active_events,
        (SELECT COUNT(*) FROM applications) AS total_applications
    `);

    res.json({
      totalUsers: parseInt(result.rows[0].total_users),
      totalEvents: parseInt(result.rows[0].total_events),
      activeEvents: parseInt(result.rows[0].active_events),
      totalApplications: parseInt(result.rows[0].total_applications),
    });
  } catch (err) {
    res.status(500).json({ error: "Stats fetch failed" });
  }
};


module.exports = {
  getUsers,
  getEvents,
  getApplications,
  getStats,
};
