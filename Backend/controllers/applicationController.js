const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");
const { applyStrike, MAX_STRIKE_REASON_LENGTH } = require("../services/strikeService");
const {
  notifyCompletedEventsForVolunteer,
} = require("../services/eventCompletionNotificationService");

const SAFE_WINDOW_HOURS = 72;
const LOCK_WINDOW_HOURS = 48;

const buildEventStartDate = (event) => {
  if (!event?.event_date) return null;

  const datePart = new Date(event.event_date).toISOString().slice(0, 10);
  let timePart = "00:00:00";
  if (event.start_time) {
    const raw = event.start_time.toString();
    const direct = raw.match(/(\d{2}:\d{2}:\d{2})/);
    if (direct) {
      timePart = direct[1];
    } else {
      const parsed = new Date(raw);
      if (!Number.isNaN(parsed.getTime())) {
        timePart = parsed.toISOString().slice(11, 19);
      }
    }
  }

  return new Date(`${datePart}T${timePart}Z`);
};

const promoteWaitlistedVolunteer = async ({ client, eventId }) => {
  const waitlisted = await client.query(
    `
    SELECT id, volunteer_id
    FROM applications
    WHERE event_id = $1
      AND status = 'waitlisted'
    ORDER BY applied_at ASC
    LIMIT 1
    FOR UPDATE
    `,
    [eventId]
  );

  if (waitlisted.rowCount === 0) {
    return null;
  }

  const promotedApp = waitlisted.rows[0];

  await client.query(
    `
    UPDATE applications
    SET status = 'approved'
    WHERE id = $1
    `,
    [promotedApp.id]
  );

  return promotedApp;
};

// ================= APPLY TO EVENT =================
exports.applyToEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    const volunteerId = req.user.id;
    const rawExperience = (req.body?.priorExperience ?? req.body?.prior_experience ?? "")
      .toString()
      .trim();
    const priorExperience = rawExperience.length > 0 ? rawExperience : null;
    const rawAvailability = (req.body?.availabilityStatus ?? req.body?.availability_status ?? "")
      .toString()
      .trim()
      .toLowerCase();
    const availabilityStatus = ["available", "partial", "unsure"].includes(rawAvailability)
      ? rawAvailability
      : "available";

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
      INSERT INTO applications (
        event_id,
        volunteer_id,
        status,
        prior_experience,
        availability_status
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, status, applied_at
      `,
      [eventId, volunteerId, nextStatus, priorExperience, availabilityStatus]
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
      SELECT
        a.id,
        CASE
          WHEN a.status = 'accepted' THEN 'approved'
          WHEN a.status IN ('pending', 'waitlisted')
            AND e.status NOT IN ('draft', 'deleted')
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
            THEN 'rejected'
          ELSE a.status
        END AS status,
        COALESCE(a.attendance_status, 'unmarked') AS attendance_status,
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
        (
          a.status IN ('pending', 'waitlisted')
          AND e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS review_closed
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE a.event_id = $1 AND a.volunteer_id = $2
      `,
      [eventId, volunteerId]
    );

    if (result.rows.length === 0) {
      return res.json({ applied: false });
    }

    res.json({
      applied: true,
      status: result.rows[0].status,
      applicationId: result.rows[0].id,
      attendanceStatus: result.rows[0].attendance_status,
      eventStatus: result.rows[0].event_status,
      eventCompleted: result.rows[0].event_completed === true,
      reviewClosed: result.rows[0].review_closed === true,
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
          WHEN a.status IN ('pending', 'waitlisted')
            AND e.status NOT IN ('draft', 'deleted')
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
            THEN 'rejected'
          ELSE a.status
        END AS status,
        COALESCE(a.attendance_status, 'unmarked') AS attendance_status,
        COALESCE(a.is_shortlisted, false) AS is_shortlisted,
        COALESCE(a.availability_status, 'available') AS availability_status,
        a.applied_at,
        a.volunteer_cancel_reason,
        a.volunteer_cancelled_at,
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
        (
          a.status IN ('pending', 'waitlisted')
          AND e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS review_closed,
        u.id AS volunteer_id,
        u.name,
        u.profile_picture_url,
        u.city
      FROM applications a
      JOIN events e ON e.id = a.event_id
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
          WHEN a.status = 'accepted' THEN 'approved'
          WHEN a.status IN ('pending', 'waitlisted')
            AND e.status NOT IN ('draft', 'deleted')
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
            THEN 'rejected'
          ELSE a.status
        END AS status,
        a.admin_cancel_reason,
        a.volunteer_cancel_reason,
        a.cancellation_supporting_document_url,
        a.cancellation_window,
        a.strike_issued,
        a.warning_issued,
        a.volunteer_cancelled_at,
        a.strike_appeal_status,
        a.strike_appeal_submitted_at,
        COALESCE(a.attendance_status, 'unmarked') AS attendance_status,
        a.attendance_marked_at,
        a.prior_experience,
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
        e.start_time,
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
        (
          a.status IN ('pending', 'waitlisted')
          AND e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS review_closed,
        EXISTS (
          SELECT 1
          FROM ratings r
          WHERE r.event_id = a.event_id
            AND r.rater_id = a.volunteer_id
            AND r.ratee_id = e.organiser_id
        ) AS has_rated,
        e.event_type,
        e.payment_amount,
        e.payment_rate_type,
        COALESCE(
          array_agg(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          '{}'
        ) AS categories
      FROM applications a
      JOIN events e ON e.id = a.event_id
      LEFT JOIN event_categories ec ON ec.event_id = e.id
      LEFT JOIN categories c ON c.id = ec.category_id
      WHERE a.volunteer_id = $1
      GROUP BY a.id, a.status, a.admin_cancel_reason, a.volunteer_cancel_reason, a.cancellation_supporting_document_url,
           a.cancellation_window, a.strike_issued, a.warning_issued, a.volunteer_cancelled_at,
           a.strike_appeal_status, a.strike_appeal_submitted_at, a.attendance_status, a.attendance_marked_at,
            a.applied_at, a.compensation_status, e.id, e.organiser_id, e.title, e.location,
                e.event_date, e.start_time, e.end_date, e.end_time, e.status, e.event_type, e.payment_amount, e.payment_rate_type
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

// ================= VOLUNTEER CANCEL APPLICATION =================
exports.cancelMyApplication = async (req, res) => {
  const client = await pool.connect();
  try {
    const applicationId = parseInt(req.params.id, 10);
    const volunteerId = req.user?.id;

    if (!Number.isInteger(applicationId) || applicationId <= 0) {
      return res.status(400).json({ error: "Invalid application ID" });
    }

    if (!volunteerId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const reason = (req.body?.reason || "").toString().trim();
    const supportingDocumentUrl = (req.body?.supportingDocumentUrl || "")
      .toString()
      .trim();

    if (reason.length > MAX_STRIKE_REASON_LENGTH) {
      return res.status(400).json({ error: "Cancellation reason is too long" });
    }

    await client.query("BEGIN");

    const appRes = await client.query(
      `
      SELECT
        a.id,
        a.status,
        a.event_id,
        a.volunteer_id,
        e.title,
        e.organiser_id,
        e.event_date,
        e.start_time,
        e.volunteers_required
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE a.id = $1
        AND a.volunteer_id = $2
      FOR UPDATE
      `,
      [applicationId, volunteerId]
    );

    if (appRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Application not found" });
    }

    const app = appRes.rows[0];
    const currentStatus = (app.status || "").toString().toLowerCase();
    if (["cancelled", "rejected", "completed"].includes(currentStatus)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Application can no longer be cancelled" });
    }

    const eventStart = buildEventStartDate(app);
    if (!eventStart) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Event date is missing" });
    }

    const hoursBeforeStart = (eventStart.getTime() - Date.now()) / (1000 * 60 * 60);

    if (hoursBeforeStart <= 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        error: "Event has already started. Application can no longer be cancelled",
      });
    }

    let cancellationWindow = "outside_72";
    let warningIssued = false;
    let strikeIssued = false;
    let strikeAction = null;
    let strikeCount = null;

    if (hoursBeforeStart <= LOCK_WINDOW_HOURS) {
      cancellationWindow = "inside_48";

      if (!reason) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          error:
            "Cancellation reason is required for cancellations within 48 hours",
        });
      }

      if (!supportingDocumentUrl) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          error:
            "Supporting document is required for cancellations within 48 hours",
        });
      }

      strikeIssued = true;

      const strikeReason = `Late cancellation (within 48 hours) for event: ${app.title}`;
      const strikeResult = await applyStrike(client, {
        userId: volunteerId,
        adminId: app.organiser_id,
        reason: strikeReason,
      });
      strikeAction = strikeResult.action;
      strikeCount = strikeResult.strikeCount;
    } else if (hoursBeforeStart <= SAFE_WINDOW_HOURS) {
      cancellationWindow = "48_to_72";
      warningIssued = true;

      const repeatedWindowCancellationsRes = await client.query(
        `
        SELECT COUNT(*)::int AS count
        FROM applications
        WHERE volunteer_id = $1
          AND cancellation_window = '48_to_72'
          AND warning_issued = TRUE
        `,
        [volunteerId]
      );

      const repeatedCount = repeatedWindowCancellationsRes.rows[0]?.count || 0;
      const hasReasonContext = reason.length > 0 || supportingDocumentUrl.length > 0;

      if (repeatedCount >= 1 && !hasReasonContext) {
        strikeIssued = true;
        const strikeReason = `Repeated 48-72h cancellation without reason for event: ${app.title}`;
        const strikeResult = await applyStrike(client, {
          userId: volunteerId,
          adminId: app.organiser_id,
          reason: strikeReason,
        });
        strikeAction = strikeResult.action;
        strikeCount = strikeResult.strikeCount;
      }
    }

    await client.query(
      `
      UPDATE applications
      SET status = 'cancelled',
          volunteer_cancel_reason = $2,
          cancellation_supporting_document_url = $3,
          volunteer_cancelled_at = NOW(),
          cancellation_window = $4,
          warning_issued = $5,
          strike_issued = $6,
          strike_appeal_status = CASE WHEN $6 THEN 'eligible' ELSE strike_appeal_status END
      WHERE id = $1
      `,
      [
        applicationId,
        reason || null,
        supportingDocumentUrl || null,
        cancellationWindow,
        warningIssued,
        strikeIssued,
      ]
    );

    const promoted = await promoteWaitlistedVolunteer({
      client,
      eventId: app.event_id,
    });

    await client.query("COMMIT");

    res.json({
      success: true,
      message: "Application cancelled",
      cancellationWindow,
      warningIssued,
      strikeIssued,
      strikeAction,
      strikeCount,
      waitlistPromoted: Boolean(promoted),
    });

    try {
      if (promoted?.volunteer_id) {
        await notifyUser(promoted.volunteer_id, {
          title: "Spot available",
          body: `You were moved from waiting list to approved for ${app.title}.`,
          data: {
            type: "waitlist_promoted",
            eventId: String(app.event_id),
          },
        });
      }

      if (app.organiser_id) {
        await notifyUser(app.organiser_id, {
          title: "Volunteer cancelled",
          body: reason
            ? `A volunteer cancelled for ${app.title}. Reason: ${reason}`
            : `A volunteer cancelled for ${app.title}.`,
          data: {
            type: "volunteer_cancelled",
            eventId: String(app.event_id),
            applicationId: String(applicationId),
            strikeIssued,
            warningIssued,
            cancellationWindow,
          },
        });
      }
    } catch (notifyErr) {
      console.error("VOLUNTEER CANCEL NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("VOLUNTEER CANCEL APPLICATION ERROR:", err);
    res.status(500).json({ error: "Failed to cancel application" });
  } finally {
    client.release();
  }
};

// ================= VOLUNTEER STRIKE APPEAL =================
exports.submitStrikeAppeal = async (req, res) => {
  try {
    const applicationId = parseInt(req.params.id, 10);
    const volunteerId = req.user?.id;
    const reason = (req.body?.reason || "").toString().trim();
    const supportingDocumentUrl = (req.body?.supportingDocumentUrl || "")
      .toString()
      .trim();

    if (!Number.isInteger(applicationId) || applicationId <= 0) {
      return res.status(400).json({ error: "Invalid application ID" });
    }

    if (!reason) {
      return res.status(400).json({ error: "Appeal reason is required" });
    }

    if (!supportingDocumentUrl) {
      return res.status(400).json({ error: "Supporting document is required" });
    }

    if (reason.length > MAX_STRIKE_REASON_LENGTH) {
      return res.status(400).json({ error: "Appeal reason is too long" });
    }

    const result = await pool.query(
      `
      UPDATE applications
      SET strike_appeal_reason = $3,
          strike_appeal_document_url = $4,
          strike_appeal_status = 'pending',
          strike_appeal_submitted_at = NOW()
      WHERE id = $1
        AND volunteer_id = $2
        AND strike_issued = TRUE
      RETURNING id, event_id
      `,
      [applicationId, volunteerId, reason, supportingDocumentUrl]
    );

    if (result.rowCount === 0) {
      return res.status(400).json({ error: "No strike found for this application" });
    }

    res.json({ success: true, message: "Strike appeal submitted" });
  } catch (err) {
    console.error("SUBMIT STRIKE APPEAL ERROR:", err);
    res.status(500).json({ error: "Failed to submit strike appeal" });
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
          WHEN a.status IN ('pending', 'waitlisted')
            AND e.status NOT IN ('draft', 'deleted')
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
            THEN 'rejected'
          ELSE a.status
        END AS status,
        COALESCE(a.attendance_status, 'unmarked') AS attendance_status,
        COALESCE(a.is_shortlisted, false) AS is_shortlisted,
        COALESCE(a.availability_status, 'available') AS availability_status,
        a.attendance_marked_at,
        a.prior_experience,
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
        (
          a.status IN ('pending', 'waitlisted')
          AND e.status NOT IN ('draft', 'deleted')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ) AS review_closed,
        u.name,
        u.email,
        u.city,
        u.contact_number,
        u.profile_picture_url,
        u."isVerified" AS "isVerified",
        COALESCE(vp.skills, '{}') AS skills,
        COALESCE(vp.interests, '{}') AS interests
      FROM applications a
      JOIN users u ON u.id = a.volunteer_id
      JOIN events e ON e.id = a.event_id
      LEFT JOIN volunteer_preferences vp ON vp.user_id = u.id
      WHERE a.id = $1
        AND e.organiser_id = $2
      `,
      [applicationId, organiserId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    const app = result.rows[0];
    const volunteerId = app.volunteer_id;

    if (!volunteerId) {
      return res.status(200).json({ application: app });
    }

    const [
      badgesRes,
      categoriesRes,
      recentRes,
    ] = await Promise.all([
      pool.query(
        `
        SELECT b.id, b.name, b.description, b.threshold
        FROM user_badges ub
        JOIN badges b ON b.id = ub.badge_id
        WHERE ub.user_id = $1
          AND b.role = 'volunteer'
        ORDER BY b.threshold ASC
        `,
        [volunteerId]
      ),
      pool.query(
        `
        SELECT c.name, COUNT(*)::int AS count
        FROM applications a
        JOIN events e ON e.id = a.event_id
        JOIN event_categories ec ON ec.event_id = e.id
        JOIN categories c ON c.id = ec.category_id
        WHERE a.volunteer_id = $1
          AND e.status != 'deleted'
          AND a.status NOT IN ('rejected', 'cancelled')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
          AND COALESCE(a.attendance_status, 'unmarked') <> 'absent'
        GROUP BY c.name
        ORDER BY count DESC, c.name ASC
        LIMIT 6
        `,
        [volunteerId]
      ),
      pool.query(
        `
        SELECT
          e.title,
          e.event_date,
          e.end_date,
          e.end_time,
          e.status AS event_status,
          a.status AS application_status,
          COALESCE(a.attendance_status, 'unmarked') AS attendance_status
        FROM applications a
        JOIN events e ON e.id = a.event_id
        WHERE a.volunteer_id = $1
          AND a.id <> $2
          AND e.status != 'deleted'
          AND a.status NOT IN ('rejected', 'cancelled')
          AND (
            e.status = 'completed'
            OR NOW() >= (
              COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
            )
          )
        ORDER BY COALESCE(e.end_date, e.event_date) DESC,
                 COALESCE(e.end_time, TIME '23:59:59') DESC
        LIMIT 3
        `,
        [volunteerId, app.id]
      ),
    ]);

    const badges = badgesRes.rows || [];
    const topBadge = badges.length > 0 ? badges[badges.length - 1] : null;

    // return in a stable format
    res.status(200).json({
      application: {
        ...app,
        badges,
        top_badge: topBadge,
        category_summary: categoriesRes.rows || [],
        recent_participation: recentRes.rows || [],
      },
    });
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
      SELECT
        id,
        status,
        volunteers_required,
        (
          status NOT IN ('draft', 'deleted')
          AND NOW() >= (
            COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')
          )
        ) AS event_completed
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
    const eventCompleted = eventResult.rows[0].event_completed === true;
    if (eventStatus !== "open" || eventCompleted) {
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

// ================= UPDATE SHORTLIST STATUS =================
// Organiser can shortlist or unshortlist applications
exports.updateApplicationShortlist = async (req, res) => {
  try {
    const applicationId = parseInt(req.params.id, 10);
    const organiserId = req.user?.id;
    const shortlisted = req.body?.shortlisted ?? req.body?.is_shortlisted;

    if (req.user?.role !== "organiser") {
      return res.status(403).json({ error: "Only organisers can update shortlist" });
    }

    if (!Number.isInteger(applicationId) || applicationId <= 0) {
      return res.status(400).json({ error: "Invalid application ID" });
    }

    if (typeof shortlisted !== "boolean") {
      return res.status(400).json({ error: "Invalid shortlisted value" });
    }

    const existingResult = await pool.query(
      `
      SELECT
        a.id,
        e.status AS event_status,
        (
          e.status NOT IN ('draft', 'deleted')
          AND NOW() >= (
            COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          )
        ) AS event_completed
      FROM applications a
      JOIN events e ON e.id = a.event_id
      WHERE a.id = $1
        AND e.organiser_id = $2
      `,
      [applicationId, organiserId]
    );

    if (existingResult.rowCount === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    const existing = existingResult.rows[0];
    const eventStatus = (existing.event_status || "").toString().toLowerCase();
    if (eventStatus !== "open" || existing.event_completed === true) {
      return res.status(400).json({
        error: "Shortlist is closed for this event.",
      });
    }

    const result = await pool.query(
      `
      UPDATE applications a
      SET is_shortlisted = $1
      FROM events e
      WHERE a.id = $2
        AND e.id = a.event_id
        AND e.organiser_id = $3
      RETURNING a.id, a.is_shortlisted, a.event_id
      `,
      [shortlisted, applicationId, organiserId]
    );

    return res.status(200).json({
      success: true,
      application: result.rows[0],
    });
  } catch (err) {
    console.error("UPDATE SHORTLIST ERROR:", err);
    return res.status(500).json({ error: "Failed to update shortlist" });
  }
};

