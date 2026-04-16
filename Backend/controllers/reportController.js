const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

const VALID_TARGET_TYPES = new Set(["user", "event", "chat_message"]);
const VALID_REPORT_STATUSES = new Set(["pending", "resolved", "dismissed", "all"]);
const VALID_REPORT_TYPES = new Set(["user", "event", "chat_message", "all"]);
const MAX_REASON_LENGTH = 255;
const MAX_DETAILS_LENGTH = 1000;

const normalizeString = (value) =>
  value == null ? "" : String(value).trim();

exports.createReport = async (req, res) => {
  try {
    const reporterId = req.user?.id;
    const targetType = normalizeString(req.body?.targetType).toLowerCase();
    const targetId = parseInt(req.body?.targetId, 10);
    const reason = normalizeString(req.body?.reason);
    const details = normalizeString(req.body?.details);

    if (!reporterId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!VALID_TARGET_TYPES.has(targetType)) {
      return res.status(400).json({ error: "Invalid target type" });
    }

    if (!targetId || Number.isNaN(targetId)) {
      return res.status(400).json({ error: "Invalid target ID" });
    }

    if (!reason) {
      return res.status(400).json({ error: "Reason is required" });
    }

    if (reason.length > MAX_REASON_LENGTH) {
      return res.status(400).json({ error: "Reason is too long" });
    }

    if (details.length > MAX_DETAILS_LENGTH) {
      return res.status(400).json({ error: "Details are too long" });
    }

    if (targetType === "user") {
      if (targetId === reporterId) {
        return res.status(400).json({ error: "You cannot report yourself" });
      }

      const userRes = await pool.query(
        "SELECT id FROM users WHERE id = $1",
        [targetId]
      );
      if (userRes.rowCount === 0) {
        return res.status(404).json({ error: "User not found" });
      }
    }

    let targetEvent = null;

    if (targetType === "event") {
      const eventRes = await pool.query(
        `
        SELECT
          id,
          organiser_id,
          title,
          status,
          (
            NOW() <= (
              COALESCE(end_date, event_date) + COALESCE(end_time, TIME '23:59:59')
              + INTERVAL '48 hours'
            )
          ) AS within_attendance_grace
        FROM events
        WHERE id = $1
        `,
        [targetId]
      );
      if (eventRes.rowCount === 0) {
        return res.status(404).json({ error: "Event not found" });
      }
      targetEvent = eventRes.rows[0];

      if (reason.toLowerCase() === "attendance reopen request") {
        if (targetEvent.organiser_id !== reporterId) {
          return res.status(403).json({
            error: "Only the organiser can request attendance reopen",
          });
        }
        if (targetEvent.status !== "completed") {
          return res.status(400).json({
            error: "Attendance reopen can only be requested for completed events",
          });
        }
        if (targetEvent.within_attendance_grace === true) {
          return res.status(400).json({
            error: "Attendance is still within the 48-hour grace window",
          });
        }
      }
    }

    if (targetType === "chat_message") {
      const msgRes = await pool.query(
        `
        SELECT m.id, m.sender_id, t.organiser_id, t.volunteer_id
        FROM chat_messages m
        JOIN chat_threads t ON t.id = m.thread_id
        WHERE m.id = $1
        `,
        [targetId]
      );

      if (msgRes.rowCount === 0) {
        return res.status(404).json({ error: "Message not found" });
      }

      const row = msgRes.rows[0];
      if (row.sender_id === reporterId) {
        return res.status(400).json({ error: "You cannot report your message" });
      }

      if (row.organiser_id !== reporterId && row.volunteer_id !== reporterId) {
        return res.status(403).json({ error: "Not allowed to report" });
      }
    }

    const existingPendingReport = await pool.query(
      `
      SELECT id
      FROM reports
      WHERE reporter_id = $1
        AND target_type = $2
        AND target_id = $3
        AND LOWER(reason) = LOWER($4)
        AND status = 'pending'
      LIMIT 1
      `,
      [reporterId, targetType, targetId, reason]
    );

    if (existingPendingReport.rowCount > 0) {
      return res.status(409).json({
        error: "A similar pending report already exists for this issue",
      });
    }

    const insertRes = await pool.query(
      `
      INSERT INTO reports (reporter_id, target_type, target_id, reason, details)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, reporter_id, target_type, target_id, reason, details, status, created_at
      `,
      [reporterId, targetType, targetId, reason, details || null]
    );

    const createdReport = insertRes.rows[0];

    if (
      targetType === "event" &&
      reason.toLowerCase() === "unpaid compensation" &&
      targetEvent?.organiser_id &&
      targetEvent.organiser_id !== reporterId
    ) {
      try {
        await notifyUser(targetEvent.organiser_id, {
          title: "Payment issue reported",
          body: `A volunteer reported unpaid compensation for ${targetEvent.title}.`,
          data: {
            type: "payment_issue_reported",
            reportId: String(createdReport.id),
            eventId: String(targetId),
          },
        });
      } catch (notifyErr) {
        console.error("PAYMENT ISSUE REPORT NOTIFY ERROR:", notifyErr);
      }
    }

    return res.status(201).json(createdReport);
  } catch (err) {
    console.error("CREATE REPORT ERROR:", err);
    return res.status(500).json({ error: "Failed to submit report" });
  }
};

exports.getMyReports = async (req, res) => {
  try {
    const reporterId = req.user?.id;
    if (!reporterId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;

    const status = (req.query.status || "all").toString().toLowerCase();
    const type = (req.query.type || "all").toString().toLowerCase();

    if (!VALID_REPORT_STATUSES.has(status)) {
      return res.status(400).json({ error: "Invalid status filter" });
    }

    if (!VALID_REPORT_TYPES.has(type)) {
      return res.status(400).json({ error: "Invalid type filter" });
    }

    const params = [reporterId];
    const where = [`r.reporter_id = $1`];

    if (status !== "all") {
      params.push(status);
      where.push(`r.status = $${params.length}`);
    }

    if (type !== "all") {
      params.push(type);
      where.push(`r.target_type = $${params.length}`);
    }

    const whereClause = `WHERE ${where.join(" AND ")}`;

    const baseFrom = `
      FROM reports r
      LEFT JOIN users u ON r.target_type = 'user' AND r.target_id = u.id
      LEFT JOIN events e ON r.target_type = 'event' AND r.target_id = e.id
      LEFT JOIN users o ON e.organiser_id = o.id
      LEFT JOIN chat_messages m ON r.target_type = 'chat_message' AND r.target_id = m.id
      LEFT JOIN users mu ON m.sender_id = mu.id
    `;

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
        r.id,
        r.target_type,
        r.target_id,
        r.reason,
        r.details,
        r.status,
        r.admin_note,
        r.action_taken,
        r.resolved_at,
        r.created_at,
        u.name AS target_user_name,
        u.email AS target_user_email,
        e.title AS target_event_title,
        o.name AS organiser_name,
        m.message AS target_message,
        mu.name AS message_sender_name
      ${baseFrom}
      ${whereClause}
      ORDER BY r.created_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}
      `,
      listParams
    );

    return res.json({
      items: listRes.rows,
      page,
      totalPages,
      total,
    });
  } catch (err) {
    console.error("GET MY REPORTS ERROR:", err);
    return res.status(500).json({ error: "Failed to fetch reports" });
  }
};
