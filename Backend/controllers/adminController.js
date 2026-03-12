const pool = require("../config/db");
const { notifyUser, notifyUsers } = require("../services/notificationService");
const {
  MAX_STRIKE_REASON_LENGTH,
  applyStrike,
  recalculateUserStrikeState,
} = require("../services/strikeService");

// ================= GET ALL USERS =================
const getUsers = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;

    const countResult = await pool.query("SELECT COUNT(*) FROM users");
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.max(Math.ceil(total / limit), 1);

    const users = await pool.query(
      `SELECT 
         u.id,
         u.name,
         u.email,
         u.role,
         u.status,
         u.created_at,
         u.profile_picture_url,
         u.city,
         u.contact_number,
         u."isVerified",
         u.suspended_until,
         u.suspension_reason,
         u.admin_note,
         (SELECT COUNT(*)::int FROM user_strikes s WHERE s.user_id = u.id) AS strike_count,
         COALESCE(
           (
             SELECT json_agg(
               json_build_object(
                 'id', s.id,
                 'reason', s.reason,
                 'created_at', s.created_at
               )
               ORDER BY s.created_at DESC
             )
             FROM user_strikes s
             WHERE s.user_id = u.id
           ),
           '[]'::json
         ) AS strike_history
       FROM users u
       ORDER BY u.id DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json({
      items: users.rows,
      page,
      totalPages,
      total,
    });
  } catch (err) {
    console.error("GET USERS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

// ================= GET ALL EVENTS =================
const getEvents = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;

    const countResult = await pool.query(`
      SELECT COUNT(*)
      FROM events e
      JOIN users u ON e.organiser_id = u.id
    `);
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.max(Math.ceil(total / limit), 1);

    const events = await pool.query(
      `SELECT e.*, u.name AS organiser_name
       FROM events e
       JOIN users u ON e.organiser_id = u.id
       ORDER BY e.id DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json({
      items: events.rows,
      page,
      totalPages,
      total,
    });
  } catch (err) {
    console.error("GET EVENTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
};

// ================= GET ALL APPLICATIONS =================
const getApplications = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;
    const rawEventId = req.query.eventId;
    const hasEventIdFilter =
      rawEventId !== undefined &&
      rawEventId !== null &&
      String(rawEventId).trim() !== "";

    let eventId = null;
    if (hasEventIdFilter) {
      eventId = parseInt(String(rawEventId), 10);
      if (!Number.isInteger(eventId) || eventId <= 0) {
        return res.status(400).json({ error: "Invalid event ID" });
      }
    }

    const filterValues = hasEventIdFilter ? [eventId] : [];
    const whereClause = hasEventIdFilter ? "WHERE a.event_id = $1" : "";
    const normalizedStatusExpr = `
      CASE
        WHEN a.status IN ('accepted', 'completed') THEN 'approved'
        WHEN a.status = 'waitlisted' THEN 'pending'
        ELSE a.status
      END
    `;
    const joinedFromClause = `
      FROM applications a
      JOIN users u ON a.volunteer_id = u.id
      JOIN events e ON a.event_id = e.id
      JOIN users o ON e.organiser_id = o.id
      ${whereClause}
    `;

    const countResult = await pool.query(
      `SELECT COUNT(*) ${joinedFromClause}`,
      filterValues
    );
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.max(Math.ceil(total / limit), 1);
    const summaryResult = await pool.query(
      `
      SELECT
        ${normalizedStatusExpr} AS status,
        COUNT(*)::int AS count
      ${joinedFromClause}
      GROUP BY 1
      `,
      filterValues
    );

    const summary = {
      applied: total,
      approved: 0,
      pending: 0,
      rejected: 0,
      cancelled: 0,
      no_show: 0,
    };

    for (const row of summaryResult.rows) {
      const status = String(row.status || "").toLowerCase();
      const count = parseInt(row.count, 10) || 0;

      if (status === "approved") {
        summary.approved += count;
      } else if (status === "rejected") {
        summary.rejected += count;
      } else if (status === "cancelled") {
        summary.cancelled += count;
      } else if (status === "no_show") {
        summary.no_show += count;
      } else {
        summary.pending += count;
      }
    }

    const apps = await pool.query(
      `SELECT 
         a.id,
         a.event_id,
          ${normalizedStatusExpr} AS status,
         a.admin_cancel_reason,
         a.volunteer_cancel_reason,
         a.cancellation_supporting_document_url,
         a.cancellation_window,
         a.warning_issued,
         a.strike_issued,
         a.strike_appeal_reason,
         a.strike_appeal_document_url,
         a.strike_appeal_status,
         a.strike_appeal_submitted_at,
         a.strike_appeal_reviewed_at,
         a.strike_appeal_review_note,
         a.applied_at,
         u.name AS volunteer_name,
         u.email AS volunteer_email,
         u.city AS volunteer_city,
         e.title AS event_title,
         e.event_date,
         e.created_at AS event_created_at,
         o.name AS organiser_name
        ${joinedFromClause}
        ORDER BY a.applied_at DESC
        LIMIT $${filterValues.length + 1} OFFSET $${filterValues.length + 2}`,
      [...filterValues, limit, offset]
    );

    res.json({
      items: apps.rows,
      page,
      totalPages,
      total,
      summary,
    });
  } catch (err) {
    console.error("GET APPLICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
};

const reviewStrikeAppeal = async (req, res) => {
  const client = await pool.connect();
  try {
    const applicationId = parseInt(req.params.id, 10);
    const approved = Boolean(req.body?.approved);
    const note = (req.body?.note || "").toString().trim();

    if (!Number.isInteger(applicationId) || applicationId <= 0) {
      return res.status(400).json({ error: "Invalid application ID" });
    }

    await client.query("BEGIN");

    const appRes = await client.query(
      `
      SELECT id, volunteer_id, strike_appeal_status, strike_appeal_document_url
      FROM applications
      WHERE id = $1
      FOR UPDATE
      `,
      [applicationId]
    );

    if (appRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Application not found" });
    }

    const app = appRes.rows[0];
    if (app.strike_appeal_status !== "pending") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "No pending appeal for this application" });
    }

    if (!app.strike_appeal_document_url) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Appeal is missing supporting document" });
    }

    let removedStrikeId = null;
    if (approved) {
      const strikeRes = await client.query(
        `
        SELECT id
        FROM user_strikes
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE
        `,
        [app.volunteer_id]
      );

      if (strikeRes.rowCount > 0) {
        removedStrikeId = strikeRes.rows[0].id;
        await client.query("DELETE FROM user_strikes WHERE id = $1", [removedStrikeId]);
      }

      await recalculateUserStrikeState(client, {
        userId: app.volunteer_id,
        reasonForPenalty: "Strike appeal approved",
      });
    }

    await client.query(
      `
      UPDATE applications
      SET strike_appeal_status = $2,
          strike_appeal_review_note = $3,
          strike_appeal_reviewed_at = NOW()
      WHERE id = $1
      `,
      [applicationId, approved ? "approved" : "rejected", note || null]
    );

    await client.query("COMMIT");

    res.json({
      success: true,
      status: approved ? "approved" : "rejected",
      removedStrikeId,
    });

    try {
      await notifyUser(app.volunteer_id, {
        title: "Strike appeal reviewed",
        body: approved
          ? "Your strike appeal was approved and your latest strike was removed."
          : "Your strike appeal was rejected. The strike remains on your account.",
        data: {
          type: "strike_appeal_reviewed",
          applicationId: String(applicationId),
          status: approved ? "approved" : "rejected",
        },
      });
    } catch (notifyErr) {
      console.error("REVIEW STRIKE APPEAL NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("REVIEW STRIKE APPEAL ERROR:", err);
    res.status(500).json({ error: "Failed to review strike appeal" });
  } finally {
    client.release();
  }
};

const getStats = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM users) AS total_users,
        (
          SELECT COUNT(*)
          FROM events e
          JOIN users u ON e.organiser_id = u.id
        ) AS total_events,
        (
          SELECT COUNT(*)
          FROM events e
          JOIN users u ON e.organiser_id = u.id
          WHERE e.status = 'open'
        ) AS active_events,
        (
          SELECT COUNT(*)
          FROM applications a
          JOIN users v ON a.volunteer_id = v.id
          JOIN events e ON a.event_id = e.id
          JOIN users o ON e.organiser_id = o.id
        ) AS total_applications,
        (SELECT COUNT(*) FROM verification_requests WHERE status = 'pending') AS pending_verifications,
        (SELECT COUNT(*) FROM reports WHERE status = 'pending') AS pending_reports
    `);

    res.json({
      totalUsers: parseInt(result.rows[0].total_users),
      totalEvents: parseInt(result.rows[0].total_events),
      activeEvents: parseInt(result.rows[0].active_events),
      totalApplications: parseInt(result.rows[0].total_applications),
      pendingVerifications: parseInt(result.rows[0].pending_verifications),
      pendingReports: parseInt(result.rows[0].pending_reports),
    });
  } catch (err) {
    res.status(500).json({ error: "Stats fetch failed" });
  }
 };

const getStatsTimeseries = async (req, res) => {
  try {
    const days = Math.max(parseInt(req.query.days || "7", 10), 1);

    const result = await pool.query(
      `
      WITH days AS (
        SELECT generate_series(
          CURRENT_DATE - ($1::int - 1),
          CURRENT_DATE,
          interval '1 day'
        )::date AS day
      ),
      event_counts AS (
        SELECT e.created_at::date AS day, COUNT(*)::int AS count
        FROM events e
        JOIN users u ON e.organiser_id = u.id
        WHERE e.created_at::date >= CURRENT_DATE - ($1::int - 1)
        GROUP BY e.created_at::date
      ),
      application_counts AS (
        SELECT a.applied_at::date AS day, COUNT(*)::int AS count
        FROM applications a
        JOIN users v ON a.volunteer_id = v.id
        JOIN events e ON a.event_id = e.id
        JOIN users o ON e.organiser_id = o.id
        WHERE a.applied_at::date >= CURRENT_DATE - ($1::int - 1)
        GROUP BY a.applied_at::date
      )
      SELECT d.day,
             COALESCE(e.count, 0) AS events,
             COALESCE(a.count, 0) AS applications
      FROM days d
      LEFT JOIN event_counts e ON e.day = d.day
      LEFT JOIN application_counts a ON a.day = d.day
      ORDER BY d.day
      `,
      [days]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("STATS TIMESERIES ERROR:", err);
    res.status(500).json({ error: "Stats timeseries fetch failed" });
  }
};

const updateUserStatus = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { status } = req.body;

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    if (!["active", "inactive", "banned"].includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }

    const userRes = await pool.query("SELECT id, role FROM users WHERE id = $1", [
      userId,
    ]);

    if (userRes.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    if (userRes.rows[0].role === "admin") {
      return res.status(400).json({ error: "Cannot change admin user status" });
    }

    const result = await pool.query(
      `UPDATE users
       SET status = $1,
           suspended_until = NULL,
           suspension_reason = NULL
       WHERE id = $2
       RETURNING id, status`,
      [status, userId]
    );

    res.json({
      message: "User status updated",
      user: result.rows[0],
    });

    try {
      await notifyUser(userId, {
        title: "Account status update",
        body: `Your account status is now ${status}.`,
        data: { type: "account_status", status },
      });
    } catch (notifyErr) {
      console.error("USER STATUS NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("UPDATE USER STATUS ERROR:", err);
    res.status(500).json({ error: "Failed to update user status" });
  }
};

const updateUserNote = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const note = (req.body?.note || "").toString().trim();

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    if (note.length > 1000) {
      return res.status(400).json({ error: "Note is too long" });
    }

    const result = await pool.query(
      "UPDATE users SET admin_note = $1 WHERE id = $2 RETURNING id, admin_note",
      [note || null, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({ message: "User note updated", user: result.rows[0] });
  } catch (err) {
    console.error("UPDATE USER NOTE ERROR:", err);
    res.status(500).json({ error: "Failed to update user note" });
  }
};

const addUserStrike = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const adminId = req.user?.id;
    const reason = (req.body?.reason || "").toString().trim();

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    if (!adminId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!reason) {
      return res.status(400).json({ error: "Strike reason is required" });
    }

    if (reason.length > MAX_STRIKE_REASON_LENGTH) {
      return res.status(400).json({ error: "Strike reason is too long" });
    }

    let strikeResult;
    try {
      strikeResult = await applyStrike(pool, { userId, adminId, reason });
    } catch (applyErr) {
      if (applyErr.status) {
        return res.status(applyErr.status).json({ error: applyErr.message });
      }
      throw applyErr;
    }

    const { strikeCount, action, suspendedUntil, status } = strikeResult;

    res.json({ strikeCount, action, suspendedUntil, status });

    try {
      await notifyUser(userId, {
        title: "Account notice",
        body:
          action === "warning"
            ? `You received a strike on your account. Reason: ${reason}`
            : action === "banned"
                ? `Your account has been banned. Reason: ${reason}`
                : `Your account has been suspended. Reason: ${reason}`,
        data: { type: "account_strike", action, strikeCount, reason },
      });
    } catch (notifyErr) {
      console.error("STRIKE NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("ADD STRIKE ERROR:", err);
    res.status(500).json({ error: "Failed to add strike" });
  }
};

const resetUserStrikes = async (req, res) => {
  const client = await pool.connect();
  try {
    const userId = parseInt(req.params.id, 10);

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    await client.query("BEGIN");

    const userRes = await client.query(
      "SELECT id, role, status FROM users WHERE id = $1 FOR UPDATE",
      [userId]
    );

    if (userRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "User not found" });
    }

    if (userRes.rows[0].role === "admin") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Cannot reset admin user strikes" });
    }

    const previousStatus = userRes.rows[0].status;
    await client.query("DELETE FROM user_strikes WHERE user_id = $1", [userId]);
    await recalculateUserStrikeState(client, { userId });
    if (previousStatus === "inactive") {
      await client.query(
        `UPDATE users
         SET status = 'inactive',
             suspended_until = NULL,
             suspension_reason = NULL
         WHERE id = $1`,
        [userId]
      );
    }
    await client.query("COMMIT");

    res.json({ message: "User strikes reset", strikeCount: 0 });

    try {
      await notifyUser(userId, {
        title: "Account restored",
        body: "Your strikes were reset and any active suspension was cleared.",
        data: { type: "account_restored" },
      });
    } catch (notifyErr) {
      console.error("RESET STRIKES NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("RESET STRIKES ERROR:", err);
    res.status(500).json({ error: "Failed to reset strikes" });
  } finally {
    client.release();
  }
};

const suspendUser = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const days = parseInt(req.body?.days, 10);
    const reason = (req.body?.reason || "").toString().trim();

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    if (!days || Number.isNaN(days) || days < 1 || days > 365) {
      return res.status(400).json({ error: "Invalid suspension days" });
    }

    if (!reason) {
      return res.status(400).json({ error: "Suspension reason is required" });
    }

    if (reason.length > MAX_STRIKE_REASON_LENGTH) {
      return res.status(400).json({ error: "Suspension reason is too long" });
    }

    const userRes = await pool.query(
      "SELECT id, role, status FROM users WHERE id = $1",
      [userId]
    );

    if (userRes.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    if (userRes.rows[0].role === "admin") {
      return res.status(400).json({ error: "Cannot suspend admin users" });
    }

    const result = await pool.query(
      `UPDATE users
       SET suspended_until = NOW() + ($2 || ' days')::interval,
           suspension_reason = $3
       WHERE id = $1
       RETURNING suspended_until`,
      [userId, days, reason]
    );

    res.json({
      message: "User suspended",
      suspendedUntil: result.rows[0]?.suspended_until || null,
    });

    try {
      await notifyUser(userId, {
        title: "Account suspended",
        body: `Your account has been suspended for ${days} days. Reason: ${reason}`,
        data: {
          type: "account_suspension",
          days: String(days),
          reason,
        },
      });
    } catch (notifyErr) {
      console.error("SUSPEND USER NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("SUSPEND USER ERROR:", err);
    res.status(500).json({ error: "Failed to suspend user" });
  }
};

const unsuspendUser = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    if (!userId || Number.isNaN(userId)) {
      return res.status(400).json({ error: "Invalid user ID" });
    }

    const result = await pool.query(
      `UPDATE users
       SET suspended_until = NULL,
           suspension_reason = NULL
       WHERE id = $1
       RETURNING id`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({ message: "User unsuspended" });

    try {
      await notifyUser(userId, {
        title: "Account restored",
        body: "Your account suspension has been lifted.",
        data: {
          type: "account_unsuspended",
        },
      });
    } catch (notifyErr) {
      console.error("UNSUSPEND USER NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("UNSUSPEND USER ERROR:", err);
    res.status(500).json({ error: "Failed to unsuspend user" });
  }
};

  const cancelApplication = async (req, res) => {
  try {
    const appId = req.params.id;
    const reason = (req.body?.reason || "").toString().trim();

    if (!reason) {
      return res
        .status(400)
        .json({ error: "Cancellation reason is required" });
    }

    if (reason.length > 500) {
      return res
        .status(400)
        .json({ error: "Cancellation reason is too long" });
    }

    const result = await pool.query(
      `UPDATE applications
       SET status = 'cancelled', admin_cancel_reason = $1
       WHERE id = $2
       RETURNING id, volunteer_id`,
      [reason, appId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    res.json({ message: "Application cancelled" });

    try {
      const volunteerId = result.rows[0]?.volunteer_id;
      if (volunteerId) {
        await notifyUser(volunteerId, {
          title: "Application update",
          body: `Your application was cancelled by admin. Reason: ${reason}`,
          data: { type: "application_cancelled", reason },
        });
      }
    } catch (notifyErr) {
      console.error("CANCEL APPLICATION NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("CANCEL APPLICATION ERROR:", err);
    res.status(500).json({ error: "Failed to cancel application" });
  }
};

const deleteEvent = async (req, res) => {
  try {
    const eventId = req.params.id;

    const eventRes = await pool.query(
      "SELECT id, title, organiser_id FROM events WHERE id = $1",
      [eventId]
    );

    if (eventRes.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    await pool.query("UPDATE events SET status = 'deleted' WHERE id = $1", [
      eventId,
    ]);

    res.json({ message: "Event deleted" });

    try {
      const organiserId = eventRes.rows[0].organiser_id;
      const eventTitle = eventRes.rows[0].title || "An event";
      const volunteerRes = await pool.query(
        `SELECT DISTINCT volunteer_id
         FROM applications
         WHERE event_id = $1
           AND status IN ('pending', 'approved', 'accepted', 'waitlisted', 'completed')`,
        [eventId]
      );
      const recipientIds = [
        ...new Set(
          [organiserId, ...volunteerRes.rows.map((row) => row.volunteer_id)].filter(
            Boolean
          )
        ),
      ];

      if (recipientIds.length > 0) {
        const activeRes = await pool.query(
          "SELECT id FROM users WHERE id = ANY($1) AND status = 'active'",
          [recipientIds]
        );
        const activeIds = activeRes.rows.map((row) => row.id);

        if (activeIds.length > 0) {
          await notifyUsers(activeIds, {
            title: "Event removed by admin",
            body: `${eventTitle} was removed by admin.`,
            data: { type: "event_deleted", eventId: String(eventId) },
          });
        }
      }
    } catch (notifyErr) {
      console.error("DELETE EVENT NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    console.error("DELETE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to delete event" });
  }
};

const hardDeleteEvent = async (req, res) => {
  const client = await pool.connect();
  try {
    const eventId = req.params.id;

    await client.query("BEGIN");

    const check = await client.query(
      "SELECT id FROM events WHERE id = $1",
      [eventId]
    );

    if (check.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Event not found" });
    }

    await client.query(
      `
      DELETE FROM chat_messages
      WHERE thread_id IN (
        SELECT id FROM chat_threads WHERE event_id = $1
      )
      `,
      [eventId]
    );

    await client.query("DELETE FROM chat_threads WHERE event_id = $1", [
      eventId,
    ]);
    await client.query("DELETE FROM ratings WHERE event_id = $1", [eventId]);
    await client.query("DELETE FROM applications WHERE event_id = $1", [
      eventId,
    ]);
    await client.query(
      "DELETE FROM event_responsibilities WHERE event_id = $1",
      [eventId]
    );
    await client.query("DELETE FROM event_categories WHERE event_id = $1", [
      eventId,
    ]);

    await client.query("DELETE FROM events WHERE id = $1", [eventId]);

    await client.query("COMMIT");
    res.json({ message: "Event permanently deleted" });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("HARD DELETE EVENT ERROR:", err);
    res.status(500).json({ error: "Failed to permanently delete event" });
  } finally {
    client.release();
  }
};

// Volunteer leaderboard
const getVolunteerLeaderboard = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        u.id,
        u.name,
        COUNT(a.id)::int AS completed_events
      FROM users u
      JOIN applications a ON a.volunteer_id = u.id
      JOIN events e ON e.id = a.event_id
      WHERE u.role = 'volunteer'
        AND a.status IN ('approved', 'accepted', 'completed')
        AND e.status != 'deleted'
        AND (
          e.status = 'completed'
          OR NOW() >= (
            COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          )
        )
      GROUP BY u.id, u.name
      ORDER BY completed_events DESC, u.name ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("VOLUNTEER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load volunteer leaderboard" });
  }
};

// Organiser leaderboard
const getOrganiserLeaderboard = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        u.id,
        u.name,
        COUNT(e.id)::int AS completed_events
      FROM users u
      JOIN events e ON e.organiser_id = u.id
      WHERE u.role = 'organiser'
        AND e.status != 'deleted'
        AND (
          e.status = 'completed'
          OR NOW() >= (
            COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
          )
        )
      GROUP BY u.id, u.name
      ORDER BY completed_events DESC, u.name ASC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("ORGANISER LEADERBOARD ERROR:", err);
    res.status(500).json({ error: "Failed to load organiser leaderboard" });
  }
};
 const evaluateBadges = async (req, res) => {
  try {
    // 1) Get all badges
    const badgesRes = await pool.query(
      "SELECT id, role, threshold FROM badges"
    );
    const badges = badgesRes.rows;

    for (const badge of badges) {
      if (badge.role === "volunteer") {
        // Volunteers: count applications for events that are completed or ended by time.
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(a.id)::int AS completed
          FROM users u
          JOIN applications a ON a.volunteer_id = u.id
          JOIN events e ON e.id = a.event_id
          WHERE u.role = 'volunteer'
            AND a.status IN ('approved', 'accepted', 'completed')
            AND e.status != 'deleted'
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
          GROUP BY u.id
        `);

        for (const u of usersRes.rows) {
          if (u.completed >= badge.threshold) {
            await pool.query(
              `
              INSERT INTO user_badges (user_id, badge_id)
              VALUES ($1, $2)
              ON CONFLICT DO NOTHING
              `,
              [u.id, badge.id]
            );
          }
        }
      }

      if (badge.role === "organiser") {
        // Organisers: count events that are completed or ended by time.
        const usersRes = await pool.query(`
          SELECT u.id, COUNT(e.id)::int AS completed
          FROM users u
          JOIN events e ON e.organiser_id = u.id
          WHERE u.role = 'organiser'
            AND e.status != 'deleted'
            AND (
              e.status = 'completed'
              OR NOW() >= (
                COALESCE(e.end_date, e.event_date) + COALESCE(e.end_time, TIME '23:59:59')
              )
            )
          GROUP BY u.id
        `);

        for (const u of usersRes.rows) {
          if (u.completed >= badge.threshold) {
            await pool.query(
              `
              INSERT INTO user_badges (user_id, badge_id)
              VALUES ($1, $2)
              ON CONFLICT DO NOTHING
              `,
              [u.id, badge.id]
            );
          }
        }
      }
    }

    res.json({ message: "Badges evaluated and awarded" });
  } catch (err) {
    console.error("EVALUATE BADGES ERROR:", err);
    res.status(500).json({ error: "Failed to evaluate badges" });
  }
};

const getBadges = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM badges ORDER BY role, threshold"
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to load badges" });
  }
};

const createBadge = async (req, res) => {
  try {
    const { name, description, role, threshold } = req.body;

    await pool.query(
      `INSERT INTO badges (name, description, role, threshold)
       VALUES ($1, $2, $3, $4)`,
      [name, description, role, threshold]
    );

    res.status(201).json({ message: "Badge created" });
  } catch (err) {
    res.status(500).json({ error: "Failed to create badge" });
  }
};

const getUserBadges = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        ub.user_id,
        b.name
      FROM user_badges ub
      JOIN badges b ON b.id = ub.badge_id
    `);

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to load user badges" });
  }
};

// ================= VERIFICATION REQUESTS (ADMIN) =================
const getVerificationRequests = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT vr.*, u.id AS user_id, u.name AS user_name, u.email AS user_email, u.role AS user_role, u."isVerified" AS "isVerified"
      FROM verification_requests vr
      JOIN users u ON vr.user_id = u.id
      ORDER BY vr.created_at DESC
    `);

    // Map rows to include a nested user object similar to previous API shape
    const mapped = result.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      role: r.role,
      idType: r.id_type,
      idNumber: r.id_number,
      idDocumentUrl: r.id_document_url,
      selfieUrl: r.selfie_url,
      organisationName: r.organisation_name,
      eventProofUrl: r.event_proof_url,
      websiteLink: r.website_link,
      status: r.status,
      adminRemark: r.admin_remark,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      user: {
        id: r.user_id,
        name: r.user_name,
        email: r.user_email,
        role: r.user_role,
        isVerified: r.isVerified,
      },
    }));

    res.json(mapped);
  } catch (err) {
    console.error("GET VERIFICATION REQUESTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch verification requests" });
  }
};

const approveVerification = async (req, res) => {
  const { requestId } = req.body;

  if (!requestId) {
    return res.status(400).json({ error: "requestId is required" });
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const check = await client.query(
      "SELECT user_id, status FROM verification_requests WHERE id = $1 FOR UPDATE",
      [requestId]
    );

    if (check.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Request not found" });
    }

    if (check.rows[0].status !== "pending") {
      await client.query("ROLLBACK");
      return res
        .status(400)
        .json({ error: "Only pending requests can be approved" });
    }

    const userId = check.rows[0].user_id;

    await client.query(
      "UPDATE verification_requests SET status = 'approved', updated_at = NOW() WHERE id = $1",
      [requestId]
    );
    await client.query(
      'UPDATE users SET "isVerified" = TRUE WHERE id = $1',
      [userId]
    );
    await client.query("COMMIT");

    res.json({ message: "User verified successfully" });

    try {
      await notifyUser(userId, {
        title: "Verification approved",
        body: "Your verification request has been approved.",
        data: { type: "verification", status: "approved" },
      });
    } catch (notifyErr) {
      console.error("APPROVE VERIFICATION NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("APPROVE VERIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to approve verification" });
  } finally {
    client.release();
  }
};

const rejectVerification = async (req, res) => {
  const client = await pool.connect();
  try {
    const { requestId, remark } = req.body;

    if (!requestId) {
      return res.status(400).json({ error: "requestId is required" });
    }

    await client.query("BEGIN");

    const check = await client.query(
      "SELECT user_id, status FROM verification_requests WHERE id = $1 FOR UPDATE",
      [requestId]
    );

    if (check.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Request not found" });
    }

    if (check.rows[0].status !== "pending") {
      await client.query("ROLLBACK");
      return res
        .status(400)
        .json({ error: "Only pending requests can be rejected" });
    }

    const userId = check.rows[0].user_id;

    await client.query(
      "UPDATE verification_requests SET status = 'rejected', admin_remark = $1, updated_at = NOW() WHERE id = $2 RETURNING id",
      [remark || null, requestId]
    );
    await client.query("COMMIT");

    res.json({ message: "Verification rejected" });

    try {
      await notifyUser(userId, {
        title: "Verification rejected",
        body: remark
          ? `Your verification request was rejected. Remark: ${remark}`
          : "Your verification request was rejected. Please review your documents and submit again.",
        data: { type: "verification", status: "rejected", remark: remark || "" },
      });
    } catch (notifyErr) {
      console.error("REJECT VERIFICATION NOTIFY ERROR:", notifyErr);
    }
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error("REJECT VERIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to reject verification" });
  } finally {
    client.release();
  }
};






const deleteBadge = async (req, res) => {
  const client = await pool.connect();
  try {
    const badgeId = req.params.id;

    await client.query("BEGIN");

    // First, delete related user_badges entries
    await client.query("DELETE FROM user_badges WHERE badge_id = $1", [badgeId]);
    
    // Then, delete the badge itself
    const result = await client.query("DELETE FROM badges WHERE id = $1", [badgeId]);

    if (result.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Badge not found" });
    }

    await client.query("COMMIT");
    res.json({ message: "Badge deleted successfully" });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("DELETE BADGE ERROR:", err);
    res.status(500).json({ error: "Failed to delete badge" });
  } finally {
    client.release();
  }
};

// ================= BROADCAST NOTIFICATIONS =================
const { broadcastNotification } = require("../services/notificationService");

const sendBroadcastNotification = async (req, res) => {
  try {
    const { title, message, targetRole } = req.body;

    if (!title || !message) {
      return res.status(400).json({ error: "Title and message are required" });
    }

    if (title.length > 100 || message.length > 500) {
      return res.status(400).json({ error: "Title or message too long" });
    }

    // Validate targetRole if provided
    if (targetRole && !['volunteer', 'organiser', 'all'].includes(targetRole)) {
      return res.status(400).json({ error: "Invalid target role" });
    }

    const roleFilter = targetRole === 'all' ? null : targetRole;

    await broadcastNotification({
      title,
      body: message,
      data: { 
        type: "broadcast", 
        targetRole: roleFilter || 'all',
        sentAt: new Date().toISOString()
      }
    }, roleFilter);

    res.json({ 
      message: "Broadcast notification sent successfully",
      targetRole: roleFilter || 'all'
    });
  } catch (err) {
    console.error("BROADCAST NOTIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to send broadcast notification" });
  }
};

const VALID_REPORT_STATUSES = new Set(["pending", "resolved", "dismissed", "all"]);
const VALID_REPORT_TYPES = new Set(["user", "event", "chat_message", "all"]);

const buildReportFilters = ({ status, type, search }) => {
  const where = [];
  const params = [];

  if (status && status !== "all") {
    params.push(status);
    where.push(`r.status = $${params.length}`);
  }

  if (type && type !== "all") {
    params.push(type);
    where.push(`r.target_type = $${params.length}`);
  }

  if (search) {
    params.push(`%${search.toLowerCase()}%`);
    const p = `$${params.length}`;
    where.push(
      `(
        LOWER(r.reason) LIKE ${p}
        OR LOWER(COALESCE(r.details, '')) LIKE ${p}
        OR LOWER(reporter.name) LIKE ${p}
        OR LOWER(reporter.email) LIKE ${p}
        OR LOWER(u.name) LIKE ${p}
        OR LOWER(u.email) LIKE ${p}
        OR LOWER(e.title) LIKE ${p}
        OR LOWER(o.name) LIKE ${p}
        OR LOWER(m.message) LIKE ${p}
        OR LOWER(mu.name) LIKE ${p}
        OR LOWER(mu.email) LIKE ${p}
      )`
    );
  }

  return {
    whereClause: where.length ? `WHERE ${where.join(" AND ")}` : "",
    params,
  };
};

const getReports = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;

    const status = (req.query.status || "pending").toString().toLowerCase();
    const type = (req.query.type || "all").toString().toLowerCase();
    const search = (req.query.search || "").toString().trim();

    if (!VALID_REPORT_STATUSES.has(status)) {
      return res.status(400).json({ error: "Invalid status filter" });
    }

    if (!VALID_REPORT_TYPES.has(type)) {
      return res.status(400).json({ error: "Invalid type filter" });
    }

    const baseFrom = `
      FROM reports r
      LEFT JOIN users reporter ON reporter.id = r.reporter_id
      LEFT JOIN users u ON r.target_type = 'user' AND r.target_id = u.id
      LEFT JOIN events e ON r.target_type = 'event' AND r.target_id = e.id
      LEFT JOIN users o ON e.organiser_id = o.id
      LEFT JOIN chat_messages m ON r.target_type = 'chat_message' AND r.target_id = m.id
      LEFT JOIN users mu ON m.sender_id = mu.id
    `;

    const { whereClause, params } = buildReportFilters({
      status,
      type,
      search,
    });

    const countRes = await pool.query(
      `SELECT COUNT(*) ${baseFrom} ${whereClause}`,
      params
    );
    const total = parseInt(countRes.rows[0].count, 10);
    const totalPages = Math.max(Math.ceil(total / limit), 1);

    const listParams = [...params, limit, offset];
    const listRes = await pool.query(
      `
      SELECT
        r.*,
        reporter.name AS reporter_name,
        reporter.email AS reporter_email,
        u.name AS target_user_name,
        u.email AS target_user_email,
        e.title AS target_event_title,
        e.organiser_id AS organiser_id,
        o.name AS organiser_name,
        m.message AS target_message,
        m.sender_id AS message_sender_id,
        mu.name AS message_sender_name,
        mu.email AS message_sender_email,
        CASE
          WHEN r.target_type = 'user' THEN r.target_id
          WHEN r.target_type = 'chat_message' THEN m.sender_id
          WHEN r.target_type = 'event' THEN e.organiser_id
          ELSE NULL
        END AS action_user_id,
        CASE
          WHEN r.target_type = 'event' THEN r.target_id
          ELSE NULL
        END AS action_event_id
      ${baseFrom}
      ${whereClause}
      ORDER BY r.created_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}
      `,
      listParams
    );

    res.json({
      items: listRes.rows,
      page,
      totalPages,
      total,
    });
  } catch (err) {
    console.error("GET REPORTS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch reports" });
  }
};

const dismissReport = async (req, res) => {
  try {
    const reportId = parseInt(req.params.id, 10);
    const adminId = req.user?.id;
    const note = (req.body?.note || "").toString().trim();

    if (!reportId || Number.isNaN(reportId)) {
      return res.status(400).json({ error: "Invalid report ID" });
    }

    if (!adminId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await pool.query(
      `
      UPDATE reports
      SET status = 'dismissed',
          admin_note = $1,
          action_taken = 'dismissed',
          resolved_by = $2,
          resolved_at = NOW(),
          updated_at = NOW()
      WHERE id = $3 AND status = 'pending'
      RETURNING id
      `,
      [note || null, adminId, reportId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Report not found or not pending" });
    }

    res.json({ message: "Report dismissed" });
  } catch (err) {
    console.error("DISMISS REPORT ERROR:", err);
    res.status(500).json({ error: "Failed to dismiss report" });
  }
};

const resolveReport = async (req, res) => {
  const client = await pool.connect();
  try {
    const reportId = parseInt(req.params.id, 10);
    const adminId = req.user?.id;
    const action = (req.body?.action || "none").toString().trim().toLowerCase();
    const note = (req.body?.note || "").toString().trim();

    if (!reportId || Number.isNaN(reportId)) {
      return res.status(400).json({ error: "Invalid report ID" });
    }

    if (!adminId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!["none", "strike", "suspend", "cancel_event"].includes(action)) {
      return res.status(400).json({ error: "Invalid action" });
    }

    await client.query("BEGIN");

    const reportRes = await client.query(
      `
      SELECT
        r.id,
        r.status,
        r.target_type,
        r.target_id,
        m.sender_id AS message_sender_id,
        e.organiser_id AS organiser_id
      FROM reports r
      LEFT JOIN chat_messages m ON r.target_type = 'chat_message' AND r.target_id = m.id
      LEFT JOIN events e ON r.target_type = 'event' AND r.target_id = e.id
      WHERE r.id = $1
      FOR UPDATE
      `,
      [reportId]
    );

    if (reportRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Report not found" });
    }

    const report = reportRes.rows[0];
    if (report.status !== "pending") {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "Report already resolved" });
    }

    let actionUserId = null;
    let actionEventId = null;
    if (report.target_type === "user") {
      actionUserId = report.target_id;
    } else if (report.target_type === "chat_message") {
      actionUserId = report.message_sender_id;
    } else if (report.target_type === "event") {
      actionEventId = report.target_id;
      actionUserId = report.organiser_id;
    }

    let actionTaken = action;
    let postCommitNotification = null;

    if (action === "strike") {
      const strikeReason = (req.body?.strikeReason || note || "").toString().trim();
      if (!actionUserId) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "No user to strike" });
      }
      if (!strikeReason) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "Strike reason is required" });
      }

      let strikeResult;
      try {
        strikeResult = await applyStrike(client, {
          userId: actionUserId,
          adminId,
          reason: strikeReason,
        });
      } catch (applyErr) {
        await client.query("ROLLBACK");
        if (applyErr.status) {
          return res.status(applyErr.status).json({ error: applyErr.message });
        }
        throw applyErr;
      }
      actionTaken = `strike_${strikeResult.action}`;
      postCommitNotification = {
        userId: actionUserId,
        errorLabel: "REPORT STRIKE NOTIFY ERROR:",
        payload: {
          title: "Account notice",
          body:
            strikeResult.action === "warning"
              ? `You received a strike. Reason: ${strikeReason}`
              : strikeResult.action === "banned"
                  ? `Your account has been banned. Reason: ${strikeReason}`
                  : `Your account has been suspended. Reason: ${strikeReason}`,
          data: {
            type: "account_strike",
            action: strikeResult.action,
            strikeCount: strikeResult.strikeCount,
            reason: strikeReason,
          },
        },
      };
    }

    if (action === "suspend") {
      const suspendDays = parseInt(req.body?.suspendDays, 10);
      const suspendReason = (req.body?.suspendReason || note || "")
        .toString()
        .trim();

      if (!actionUserId) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "No user to suspend" });
      }
      if (!suspendDays || Number.isNaN(suspendDays) || suspendDays < 1) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "Invalid suspension days" });
      }
      if (!suspendReason) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "Suspension reason is required" });
      }

      const userRes = await client.query(
        "SELECT role FROM users WHERE id = $1",
        [actionUserId]
      );
      if (userRes.rowCount === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ error: "User not found" });
      }
      if (userRes.rows[0].role === "admin") {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "Cannot suspend admin users" });
      }

      await client.query(
        `
        UPDATE users
        SET suspended_until = NOW() + ($2 || ' days')::interval,
            suspension_reason = $3
        WHERE id = $1
        `,
        [actionUserId, suspendDays, suspendReason]
      );

      actionTaken = `suspend_${suspendDays}_days`;
      postCommitNotification = {
        userId: actionUserId,
        errorLabel: "REPORT SUSPEND NOTIFY ERROR:",
        payload: {
          title: "Account suspended",
          body: `Your account has been suspended for ${suspendDays} days. Reason: ${suspendReason}`,
          data: {
            type: "account_suspension",
            days: String(suspendDays),
            reason: suspendReason,
          },
        },
      };
    }

    if (action === "cancel_event") {
      const cancelReason = (req.body?.cancelReason || note || "")
        .toString()
        .trim();
      if (!actionEventId) {
        await client.query("ROLLBACK");
        return res.status(400).json({ error: "No event to cancel" });
      }

      const result = await client.query(
        "UPDATE events SET status = 'deleted' WHERE id = $1",
        [actionEventId]
      );

      if (result.rowCount === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ error: "Event not found" });
      }

      actionTaken = "cancel_event";

      if (actionUserId) {
        postCommitNotification = {
          userId: actionUserId,
          errorLabel: "REPORT EVENT NOTIFY ERROR:",
          payload: {
            title: "Event removed",
            body: cancelReason
              ? `Your event was removed. Reason: ${cancelReason}`
              : "Your event was removed by admin.",
            data: { type: "event_removed", eventId: String(actionEventId) },
          },
        };
      }
    }

    await client.query(
      `
      UPDATE reports
      SET status = 'resolved',
          admin_note = $1,
          action_taken = $2,
          resolved_by = $3,
          resolved_at = NOW(),
          updated_at = NOW()
      WHERE id = $4
      `,
      [note || null, actionTaken, adminId, reportId]
    );

    await client.query("COMMIT");
    res.json({ message: "Report resolved", actionTaken });

    if (postCommitNotification) {
      try {
        await notifyUser(
          postCommitNotification.userId,
          postCommitNotification.payload
        );
      } catch (notifyErr) {
        console.error(postCommitNotification.errorLabel, notifyErr);
      }
    }
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("RESOLVE REPORT ERROR:", err);
    res.status(500).json({ error: "Failed to resolve report" });
  } finally {
    client.release();
  }
};

const sendTargetedNotification = async (req, res) => {
  try {
    const { title, message, userIds } = req.body;

    if (!title || !message) {
      return res.status(400).json({ error: "Title and message are required" });
    }

    if (title.length > 100 || message.length > 500) {
      return res.status(400).json({ error: "Title or message too long" });
    }

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: "userIds are required" });
    }

    const ids = userIds
      .map((id) => parseInt(id, 10))
      .filter((id) => id && !Number.isNaN(id));

    const uniqueIds = [...new Set(ids)];

    if (uniqueIds.length === 0) {
      return res.status(400).json({ error: "Invalid user IDs" });
    }

    const userRes = await pool.query(
      "SELECT id FROM users WHERE id = ANY($1) AND status = 'active'",
      [uniqueIds]
    );

    const activeIds = userRes.rows.map((r) => r.id);
    if (activeIds.length === 0) {
      return res.status(400).json({ error: "No active users to notify" });
    }

    await notifyUsers(activeIds, {
      title,
      body: message,
      data: {
        type: "targeted",
        sentAt: new Date().toISOString(),
      },
    });

    res.json({
      message: "Targeted notification sent",
      deliveredTo: activeIds.length,
    });
  } catch (err) {
    console.error("TARGETED NOTIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to send targeted notification" });
  }
};

const sendEventNotification = async (req, res) => {
  try {
    const { title, message, eventId } = req.body;
    const eventIdInt = parseInt(eventId, 10);

    if (!title || !message) {
      return res.status(400).json({ error: "Title and message are required" });
    }

    if (!eventId || Number.isNaN(eventIdInt)) {
      return res.status(400).json({ error: "Invalid event ID" });
    }

    if (title.length > 100 || message.length > 500) {
      return res.status(400).json({ error: "Title or message too long" });
    }

    const eventRes = await pool.query(
      "SELECT id, organiser_id FROM events WHERE id = $1",
      [eventIdInt]
    );

    if (eventRes.rowCount === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const organiserId = eventRes.rows[0].organiser_id;

    const volunteerRes = await pool.query(
      `SELECT DISTINCT volunteer_id
       FROM applications
       WHERE event_id = $1
         AND status IN ('approved', 'accepted', 'completed')`,
      [eventIdInt]
    );
    const volunteerIds = volunteerRes.rows
      .map((r) => r.volunteer_id)
      .filter(Boolean);

    const rawIds = [...new Set([organiserId, ...volunteerIds].filter(Boolean))];

    if (rawIds.length === 0) {
      return res.status(400).json({ error: "No users to notify" });
    }

    const activeRes = await pool.query(
      "SELECT id FROM users WHERE id = ANY($1) AND status = 'active'",
      [rawIds]
    );
    const activeIds = activeRes.rows.map((r) => r.id);

    if (activeIds.length === 0) {
      return res.status(400).json({ error: "No active users to notify" });
    }

    await notifyUsers(activeIds, {
      title,
      body: message,
      data: {
        type: "event_broadcast",
        eventId: String(eventIdInt),
        sentAt: new Date().toISOString(),
      },
    });

    res.json({
      message: "Event notification sent",
      deliveredTo: activeIds.length,
    });
  } catch (err) {
    console.error("EVENT NOTIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to send event notification" });
  }
};

module.exports = {
  getUsers,
  getEvents,
  getApplications,
  getStats,
  getStatsTimeseries,
  updateUserStatus,
  updateUserNote,
  addUserStrike,
  resetUserStrikes,
  suspendUser,
  unsuspendUser,
  cancelApplication,
  reviewStrikeAppeal,
  deleteEvent,
  hardDeleteEvent,
  getVolunteerLeaderboard,
  getOrganiserLeaderboard,
  evaluateBadges,
  getBadges,
  createBadge,
  deleteBadge,
  getUserBadges,
  getVerificationRequests,
  approveVerification,
  rejectVerification,
  sendBroadcastNotification,
  getReports,
  dismissReport,
  resolveReport,
  sendTargetedNotification,
  sendEventNotification,
};
