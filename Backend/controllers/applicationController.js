const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

// ================= APPLY TO EVENT =================
exports.applyToEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;

    // Prevent double apply
    const existing = await pool.query(
      "SELECT id FROM applications WHERE event_id = $1 AND volunteer_id = $2",
      [eventId, volunteerId]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: "Already applied" });
    }

    // Apply
    const result = await pool.query(
      `
      INSERT INTO applications (event_id, volunteer_id, status)
      VALUES ($1, $2, 'pending')
      RETURNING id, status, applied_at
      `,
      [eventId, volunteerId]
    );

    res.status(201).json({
      success: true,
      application_id: result.rows[0].id,
      status: result.rows[0].status,
      applied_at: result.rows[0].applied_at
    });
  } catch (err) {
    console.error("APPLY ERROR:", err);
    res.status(500).json({ error: "Failed to apply" });
  }
};

// ================= APPLICATION STATUS =================
exports.getApplicationStatus = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;

    const result = await pool.query(
      `
      SELECT status
      FROM applications
      WHERE event_id = $1 AND volunteer_id = $2
      `,
      [eventId, volunteerId]
    );

    if (result.rows.length === 0) {
      return res.json({ applied: false });
    }

    res.json({
      applied: true,
      status: result.rows[0].status
    });
  } catch (err) {
    console.error("STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to get status" });
  }
};

// ================= EVENT APPLICATIONS (ORGANISER) =================
exports.getEventApplications = async (req, res) => {
  try {
    const eventId = req.params.id;

    const result = await pool.query(
      `
      SELECT 
        a.id,
        a.status,
        a.applied_at,
        u.id AS volunteer_id,
        u.name,
        u.city
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      WHERE a.event_id = $1
      ORDER BY a.applied_at DESC
      `,
      [eventId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

// ================= MY APPLICATIONS (VOLUNTEER) =================
exports.getMyApplications = async (req, res) => {
  try {
    const volunteerId = req.user.id;

    const result = await pool.query(
      `
      SELECT 
        a.id,
        a.status,
        a.admin_cancel_reason,
        a.applied_at,
        COALESCE(
          CASE WHEN e.event_type = 'unpaid' THEN 'not_applicable' END,
          a.compensation_status,
          'pending'
        ) AS compensation_status,
        e.id AS event_id,
        e.title,
        e.location,
        e.event_date,
        e.event_type,
        e.payment_per_day,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories
      FROM applications a
      JOIN events e ON e.id = a.event_id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      WHERE a.volunteer_id = $1
      GROUP BY a.id, a.status, a.applied_at, a.compensation_status, e.id, e.title, e.location, e.event_date, e.event_type, e.payment_per_day
      ORDER BY a.applied_at DESC
      `,
      [volunteerId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("MY APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch my applications" });
  }
};

// ================= UPDATE COMPENSATION STATUS =================
// Volunteer self-reports compensation status
exports.updateCompensationStatus = async (req, res) => {
  try {
    const applicationId = req.params.id;
    const volunteerId = req.user.id;
    const { status } = req.body;

    const allowed = ["pending", "received", "not_applicable"];
    if (!status || !allowed.includes(status)) {
      return res.status(400).json({
        error: `Invalid status. Allowed: ${allowed.join(", ")}`,
      });
    }

    const result = await pool.query(
      `
      UPDATE applications a
      SET compensation_status =
        CASE
          WHEN e.event_type = 'unpaid' THEN 'not_applicable'
          ELSE $1
        END
      FROM events e
      WHERE a.id = $2 AND a.volunteer_id = $3 AND e.id = a.event_id
      RETURNING a.id, a.compensation_status, a.event_id, a.volunteer_id
      `,
      [status, applicationId, volunteerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.status(200).json({
      success: true,
      message: "Compensation status updated",
      application: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE COMPENSATION STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update compensation status" });
  }
};

// ================= GET SINGLE APPLICATION (DETAILS) =================
// For organiser to view one application detail
exports.getApplicationById = async (req, res) => {
  try {
    const applicationId = req.params.id;

    const result = await pool.query(
      `
      SELECT 
        a.id,
        a.status,
        a.applied_at,
        a.event_id,
        a.volunteer_id,
        u.name,
        u.email,
        u.city,
        u.contact_number
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      WHERE a.id = $1
      `,
      [applicationId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    // return in a stable format
    res.status(200).json({ application: result.rows[0] });
  } catch (err) {
    console.error("GET APPLICATION BY ID ERROR:", err);
    res.status(500).json({ error: "Failed to fetch application" });
  }
};

// ================= UPDATE APPLICATION STATUS =================
// Approve / Reject by organiser
exports.updateApplicationStatus = async (req, res) => {
  try {
    const applicationId = req.params.id;
    const { status } = req.body;

    // allow only these values (matches your existing system)
    const allowed = ["pending", "accepted", "rejected"];
    if (!status || !allowed.includes(status)) {
      return res.status(400).json({
        error: `Invalid status. Allowed: ${allowed.join(", ")}`,
      });
    }

    const result = await pool.query(
      `
      UPDATE applications
      SET status = $1
      WHERE id = $2
      RETURNING id, status, applied_at, event_id, volunteer_id
      `,
      [status, applicationId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.status(200).json({
      success: true,
      message: "Application status updated",
      application: result.rows[0],
    });

    try {
      const app = result.rows[0];
      const eventResult = await pool.query(
        "SELECT title FROM events WHERE id = $1",
        [app.event_id]
      );
      const eventTitle = eventResult.rows[0]?.title || "your event";
      const statusLabel = app.status === "accepted" ? "approved" : app.status;

      await notifyUser(app.volunteer_id, {
        title: "Application update",
        body: `Your application for ${eventTitle} was ${statusLabel}.`,
        data: { type: "application_status", status: app.status },
      });
    } catch (notifyErr) {
      console.error("APPLICATION STATUS NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("UPDATE APPLICATION STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update status" });
  }
};

