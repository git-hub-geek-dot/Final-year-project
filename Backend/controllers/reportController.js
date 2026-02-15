const pool = require("../config/db");

const VALID_TARGET_TYPES = new Set(["user", "event", "chat_message"]);
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

    if (targetType === "event") {
      const eventRes = await pool.query(
        "SELECT id FROM events WHERE id = $1",
        [targetId]
      );
      if (eventRes.rowCount === 0) {
        return res.status(404).json({ error: "Event not found" });
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

    const insertRes = await pool.query(
      `
      INSERT INTO reports (reporter_id, target_type, target_id, reason, details)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, reporter_id, target_type, target_id, reason, details, status, created_at
      `,
      [reporterId, targetType, targetId, reason, details || null]
    );

    return res.status(201).json(insertRes.rows[0]);
  } catch (err) {
    console.error("CREATE REPORT ERROR:", err);
    return res.status(500).json({ error: "Failed to submit report" });
  }
};
