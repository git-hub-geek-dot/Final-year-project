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
        (SELECT COUNT(*) FROM events WHERE status = 'open') AS active_events,
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

 const updateUserStatus = async (req, res) => {
  try {
    const userId = req.params.id;
    const { status } = req.body;

    if (!["active", "blocked"].includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }

    const result = await pool.query(
      "UPDATE users SET status = $1 WHERE id = $2 RETURNING id, status",
      [status, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({
      message: "User status updated",
      user: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE USER STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update user status" });
  }};


  const cancelApplication = async (req, res) => {
  try {
    const appId = req.params.id;

    const result = await pool.query(
      "UPDATE applications SET status = 'cancelled' WHERE id = $1",
      [appId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.json({ message: "Application cancelled" });
  } catch (err) {
    console.error("CANCEL APPLICATION ERROR:", err);
    res.status(500).json({ error: "Failed to cancel application" });
  }
};

const deleteEvent = async (req, res) => {
  try {
    const eventId = req.params.id;

    const result = await pool.query(
  "UPDATE events SET status = 'deleted' WHERE id = $1",
  [eventId]
);


    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    res.json({ message: "Event deleted" });
  } catch (err) {
    console.error("DELETE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to delete event" });
  }
};


module.exports = {
  getUsers,
  getEvents,
  getApplications,
  getStats,
  updateUserStatus,
  cancelApplication,
  deleteEvent,
};
