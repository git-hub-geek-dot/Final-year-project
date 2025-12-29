const pool = require("../config/db");

/* ============ VOLUNTEER APPLY TO EVENT ============ */
exports.applyToEvent = async (req, res) => {
  try {
    if (req.user.role !== "volunteer") {
      return res.status(403).json({ error: "Only volunteers can apply" });
    }

    const eventId = req.params.id;

    const event = await pool.query(
      "SELECT id FROM events WHERE id=$1",
      [eventId]
    );

    if (!event.rows.length) {
      return res.status(404).json({ error: "Event not found" });
    }

    const alreadyApplied = await pool.query(
      "SELECT id FROM applications WHERE event_id=$1 AND volunteer_id=$2",
      [eventId, req.user.id]
    );

    if (alreadyApplied.rows.length) {
      return res.status(400).json({ error: "Already applied" });
    }

    const app = await pool.query(
      "INSERT INTO applications (event_id, volunteer_id) VALUES ($1,$2) RETURNING *",
      [eventId, req.user.id]
    );

    res.json(app.rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Application failed" });
  }
};

/* ============ ORGANIZER VIEW APPLICANTS ============ */
exports.viewApplicants = async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Organizer only" });
    }

    const eventId = req.params.id;

    const event = await pool.query(
      "SELECT id FROM events WHERE id=$1 AND organizer_id=$2",
      [eventId, req.user.id]
    );

    if (!event.rows.length) {
      return res.status(403).json({ error: "Not your event" });
    }

    const applicants = await pool.query(
      `SELECT a.id, a.status, u.id AS volunteer_id, u.name, u.email
       FROM applications a
       JOIN users u ON a.volunteer_id = u.id
       WHERE a.event_id = $1`,
      [eventId]
    );

    res.json(applicants.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to load applicants" });
  }
};

/* ============ APPROVE / REJECT APPLICATION ============ */
exports.decideApplication = async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Organizer only" });
    }

    const { decision } = req.body;
    const appId = req.params.id;

    if (!["approve", "reject"].includes(decision)) {
      return res.status(400).json({ error: "Invalid decision" });
    }

    const app = await pool.query(
      `SELECT a.id, e.organizer_id
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.id = $1`,
      [appId]
    );

    if (!app.rows.length || app.rows[0].organizer_id !== req.user.id) {
      return res.status(403).json({ error: "Not allowed" });
    }

    const status = decision === "approve" ? "approved" : "rejected";

    await pool.query(
      "UPDATE applications SET status=$1 WHERE id=$2",
      [status, appId]
    );

    res.json({ message: `Application ${status}` });
  } catch (err) {
    res.status(500).json({ error: "Decision failed" });
  }
};

/* ============ VOLUNTEER VIEW OWN APPLICATIONS ============ */
exports.myApplications = async (req, res) => {
  try {
    if (req.user.role !== "volunteer") {
      return res.status(403).json({ error: "Volunteer only" });
    }

    const apps = await pool.query(
      `SELECT 
         a.id AS application_id,
         a.status,
         e.title,
         e.location,
         e.event_date
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.volunteer_id = $1
       ORDER BY a.applied_at DESC`,
      [req.user.id]
    );

    res.json(apps.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};
