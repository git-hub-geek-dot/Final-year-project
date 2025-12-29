const pool = require("../config/db");

/* ============ VIEW ALL USERS ============ */
exports.getAllUsers = async (req, res) => {
  try {
    const users = await pool.query(
      "SELECT id, name, email, role, status, created_at FROM users ORDER BY id DESC"
    );
    res.json(users.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

/* ============ BLOCK / UNBLOCK USER ============ */
exports.updateUserStatus = async (req, res) => {
  try {
    const userId = req.params.id;
    const { status } = req.body;

    if (!["active", "blocked"].includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }

    await pool.query(
      "UPDATE users SET status=$1 WHERE id=$2",
      [status, userId]
    );

    res.json({ message: `User ${status}` });
  } catch (err) {
    res.status(500).json({ error: "Failed to update user status" });
  }
};

/* ============ VIEW ALL EVENTS ============ */
exports.getAllEvents = async (req, res) => {
  try {
    const events = await pool.query(
      `SELECT e.*, u.name AS organizer_name
       FROM events e
       JOIN users u ON e.organizer_id = u.id
       ORDER BY e.id DESC`
    );
    res.json(events.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

/* ============ DELETE EVENT ============ */
exports.deleteEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    await pool.query("DELETE FROM events WHERE id=$1", [eventId]);
    res.json({ message: "Event deleted by admin" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete event" });
  }
};

/* ============ VIEW ALL APPLICATIONS ============ */
exports.getAllApplications = async (req, res) => {
  try {
    const apps = await pool.query(
      `SELECT 
         a.id,
         a.status,
         u.name AS volunteer_name,
         e.title AS event_title
       FROM applications a
       JOIN users u ON a.volunteer_id = u.id
       JOIN events e ON a.event_id = e.id
       ORDER BY a.applied_at DESC`
    );
    res.json(apps.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

/* ============ CANCEL APPLICATION ============ */
exports.cancelApplication = async (req, res) => {
  try {
    const appId = req.params.id;
    await pool.query(
      "UPDATE applications SET status='cancelled' WHERE id=$1",
      [appId]
    );
    res.json({ message: "Application cancelled by admin" });
  } catch (err) {
    res.status(500).json({ error: "Failed to cancel application" });
  }
};
