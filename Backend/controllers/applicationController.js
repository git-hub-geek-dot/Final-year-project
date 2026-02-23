const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");
const {
  notifyCompletedEventsForVolunteer,
} = require("../services/eventCompletionNotificationService");

// ================= APPLY TO EVENT =================
exports.applyToEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;

    // Check if user is verified
    const userCheck = await pool.query(
      'SELECT "isVerified" FROM users WHERE id = $1',
      [volunteerId]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    if (!userCheck.rows[0].isVerified) {
      return res.status(403).json({ 
        error: "Verification required",
        message: "You must be verified to apply for events"
      });
    }

    // Prevent double apply
    const existing = await pool.query(
      "SELECT id FROM applications WHERE event_id = $1 AND volunteer_id = $2",
      [eventId, volunteerId]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: "Already applied" });
    }

    const eventResult = await pool.query(
      `
      SELECT id, status, volunteers_required
      FROM events
      WHERE id = $1
      `,
      [eventId]
    );

    if (eventResult.rows.length === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const event = eventResult.rows[0];
    if (event.status !== "open") {
      return res.status(400).json({ error: "Applications are closed" });
    }

    // Check application deadline
    if (event.application_deadline) {
      const deadlineDate = new Date(event.application_deadline);
      const now = new Date();
      
      if (now > deadlineDate) {
        return res.status(400).json({ error: "Application deadline has passed" });
      }
    }

    const volunteersRequired = Number(event.volunteers_required) || 0;
    let nextStatus = "pending";

    if (volunteersRequired > 0) {
      const approvedCountResult = await pool.query(
        `
        SELECT COUNT(*)::int AS approved_count
        FROM applications
        WHERE event_id = $1
          AND status IN ('approved', 'accepted')
        `,
        [eventId]
      );

      const approvedCount = approvedCountResult.rows[0]?.approved_count ?? 0;
      if (approvedCount >= volunteersRequired) {
        nextStatus = "waitlisted";
      }
    }

    // Apply (pending by default, waitlisted if event is already full)
    const result = await pool.query(
      `
      INSERT INTO applications (event_id, volunteer_id, status)
      VALUES ($1, $2, $3)
      RETURNING id, status, applied_at
      `,
      [eventId, volunteerId, nextStatus]
    );

    res.status(201).json({
      success: true,
      application_id: result.rows[0].id,
      status: result.rows[0].status,
      applied_at: result.rows[0].applied_at,
      waitlisted: result.rows[0].status === "waitlisted",
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

    const rawStatus = (result.rows[0].status || "").toString().toLowerCase();
    const status = rawStatus === "waitlisted"
      ? "pending"
      : rawStatus === "accepted"
        ? "approved"
        : rawStatus;

    res.json({
      applied: true,
      status
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
    const organiserId = req.user?.id;

    if (req.user?.role !== "organiser") {
      return res.status(403).json({ error: "Only organisers can view event applications" });
    }

    const ownerCheck = await pool.query(
      `
      SELECT id
      FROM events
      WHERE id = $1 AND organiser_id = $2
      `,
      [eventId, organiserId]
    );

    if (ownerCheck.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const result = await pool.query(
      `
      SELECT 
        a.id,
        CASE
          WHEN a.status = 'accepted' THEN 'approved'
          ELSE a.status
        END AS status,
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

    try {
      await notifyCompletedEventsForVolunteer(volunteerId);
    } catch (notifyErr) {
      console.error("VOLUNTEER COMPLETION NOTIFY ERROR:", notifyErr);
    }

    const result = await pool.query(
      `
      SELECT 
        a.id,
        CASE
          WHEN a.status = 'waitlisted' THEN 'pending'
          WHEN a.status = 'accepted' THEN 'approved'
          ELSE a.status
        END AS status,
        a.admin_cancel_reason,
        a.applied_at,
        COALESCE(
          CASE WHEN e.event_type = 'unpaid' THEN 'not_applicable' END,
          a.compensation_status,
          'pending'
        ) AS compensation_status,
        e.id AS event_id,
        e.organiser_id,
        e.title,
        e.location,
        e.event_date,
        e.end_date,
        e.end_time,
        e.status AS event_status,
        (
          e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS event_completed,
        EXISTS (
          SELECT 1
          FROM ratings r
          WHERE r.event_id = a.event_id
            AND r.rater_id = a.volunteer_id
            AND r.ratee_id = e.organiser_id
        ) AS has_rated,
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
      GROUP BY a.id, a.status, a.applied_at, a.compensation_status, e.id, e.organiser_id, e.title, e.location, e.event_date, e.end_date, e.end_time, e.status, e.event_type, e.payment_per_day
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
    const organiserId = req.user?.id;

    if (req.user?.role !== "organiser") {
      return res.status(403).json({ error: "Only organisers can view application details" });
    }

    const result = await pool.query(
      `
      SELECT 
        a.id,
        CASE
          WHEN a.status = 'accepted' THEN 'approved'
          ELSE a.status
        END AS status,
        a.applied_at,
        a.event_id,
        a.volunteer_id,
        e.status AS event_status,
        e.event_date,
        e.end_date,
        e.end_time,
        (
          e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS event_completed,
        u.name,
        u.email,
        u.city,
        u.contact_number
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      JOIN events e ON e.id = a.event_id
      WHERE a.id = $1
        AND e.organiser_id = $2
      `,
      [applicationId, organiserId]
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
  const client = await pool.connect();
  try {
    const applicationId = parseInt(req.params.id, 10);
    const organiserId = req.user?.id;
    const requestedStatus = (req.body?.status || "").toString().toLowerCase();
    const status = requestedStatus === "accepted" ? "approved" : requestedStatus;

    if (req.user?.role !== "organiser") {
      return res.status(403).json({ error: "Only organisers can update application status" });
    }

    if (!Number.isInteger(applicationId) || applicationId <= 0) {
      return res.status(400).json({ error: "Invalid application ID" });
    }

    // Canonical status vocabulary: pending | approved | rejected.
    // Legacy clients may still send "accepted", which is normalized above.
    const allowed = ["pending", "approved", "rejected"];
    if (!status || !allowed.includes(status)) {
      return res.status(400).json({
        error: `Invalid status. Allowed: ${allowed.join(", ")}`,
      });
    }

    await client.query("BEGIN");

    const applicationResult = await client.query(
      `
      SELECT
        a.id,
        a.status,
        a.event_id,
        a.volunteer_id,
        a.applied_at
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE a.id = $1
        AND e.organiser_id = $2
      FOR UPDATE
      `,
      [applicationId, organiserId]
    );

    if (applicationResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Application not found" });
    }

    const currentApplication = applicationResult.rows[0];
    const wasAlreadyApproved =
      currentApplication.status === "approved" ||
      currentApplication.status === "accepted";

    const eventResult = await client.query(
      `
      SELECT id, status, volunteers_required
      FROM events
      WHERE id = $1
      FOR UPDATE
      `,
      [currentApplication.event_id]
    );

    if (eventResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Event not found" });
    }

    const eventStatus = (eventResult.rows[0].status || "").toString().toLowerCase();
    if (eventStatus !== "open") {
      await client.query("ROLLBACK");
      return res.status(400).json({
        error: "Applications are closed for this event.",
      });
    }

    if (status === "approved" && !wasAlreadyApproved) {
      const volunteersRequired =
        Number(eventResult.rows[0].volunteers_required) || 0;

      const approvedCountResult = await client.query(
        `
        SELECT COUNT(*)::int AS approved_count
        FROM applications
        WHERE event_id = $1
          AND status IN ('approved', 'accepted')
          AND id <> $2
        `,
        [currentApplication.event_id, applicationId]
      );

      const approvedCount = approvedCountResult.rows[0]?.approved_count ?? 0;

      if (volunteersRequired <= 0 || approvedCount >= volunteersRequired) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          error: "Cannot approve application. Volunteer slots are full.",
          approved_count: approvedCount,
          volunteers_required: volunteersRequired,
        });
      }
    }

    const result = await client.query(
      `
      UPDATE applications
      SET status = $1
      WHERE id = $2
      RETURNING id, status, applied_at, event_id, volunteer_id
      `,
      [status, applicationId]
    );

    await client.query("COMMIT");

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
      const statusLabel = app.status;

      await notifyUser(app.volunteer_id, {
        title: "Application update",
        body: `Your application for ${eventTitle} was ${statusLabel}.`,
        data: { type: "application_status", status: app.status },
      });
    } catch (notifyErr) {
      console.error("APPLICATION STATUS NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("UPDATE APPLICATION STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update status" });
  } finally {
    client.release();
  }
};

