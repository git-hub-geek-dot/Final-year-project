const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

const getThreadForUser = async (threadId, userId) => {
  const result = await pool.query(
    `
    SELECT *
    FROM chat_threads
    WHERE id = $1 AND (organiser_id = $2 OR volunteer_id = $2)
    `,
    [threadId, userId]
  );

  return result.rows[0];
};

exports.getThreads = async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      `
      SELECT
        ct.id,
        ct.event_id,
        ct.organiser_id,
        ct.volunteer_id,
        ct.created_at,
        e.title AS event_title,
        uo.name AS organiser_name,
        uv.name AS volunteer_name,
        m.message AS last_message,
        m.created_at AS last_message_at
      FROM chat_threads ct
      JOIN events e ON e.id = ct.event_id
      JOIN users uo ON uo.id = ct.organiser_id
      JOIN users uv ON uv.id = ct.volunteer_id
      LEFT JOIN LATERAL (
        SELECT message, created_at
        FROM chat_messages
        WHERE thread_id = ct.id
        ORDER BY created_at DESC
        LIMIT 1
      ) m ON true
      WHERE ct.organiser_id = $1 OR ct.volunteer_id = $1
      ORDER BY m.created_at DESC NULLS LAST, ct.created_at DESC
      `,
      [userId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("GET THREADS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch threads" });
  }
};

exports.getOrCreateThread = async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;
    const { eventId, volunteerId } = req.body;

    if (!eventId) {
      return res.status(400).json({ error: "eventId is required" });
    }

    let organiserId;
    let resolvedVolunteerId;

    if (role === "organiser") {
      if (!volunteerId) {
        return res.status(400).json({ error: "volunteerId is required" });
      }
      organiserId = userId;
      resolvedVolunteerId = volunteerId;

      const eventCheck = await pool.query(
        "SELECT id FROM events WHERE id = $1 AND organiser_id = $2",
        [eventId, organiserId]
      );
      if (eventCheck.rows.length === 0) {
        return res.status(403).json({ error: "Not your event" });
      }
    } else if (role === "volunteer") {
      resolvedVolunteerId = userId;
      const eventResult = await pool.query(
        "SELECT organiser_id FROM events WHERE id = $1",
        [eventId]
      );
      if (eventResult.rows.length === 0) {
        return res.status(404).json({ error: "Event not found" });
      }
      organiserId = eventResult.rows[0].organiser_id;
    } else {
      return res.status(403).json({ error: "Role not allowed" });
    }

    const existing = await pool.query(
      `
      SELECT *
      FROM chat_threads
      WHERE event_id = $1 AND organiser_id = $2 AND volunteer_id = $3
      `,
      [eventId, organiserId, resolvedVolunteerId]
    );

    if (existing.rows.length > 0) {
      return res.json(existing.rows[0]);
    }

    const created = await pool.query(
      `
      INSERT INTO chat_threads (event_id, organiser_id, volunteer_id)
      VALUES ($1, $2, $3)
      RETURNING *
      `,
      [eventId, organiserId, resolvedVolunteerId]
    );

    return res.status(201).json(created.rows[0]);
  } catch (err) {
    console.error("GET/CREATE THREAD ERROR:", err);
    res.status(500).json({ error: "Failed to create thread" });
  }
};

exports.getMessages = async (req, res) => {
  try {
    const userId = req.user.id;
    const threadId = parseInt(req.params.threadId, 10);

    const thread = await getThreadForUser(threadId, userId);
    if (!thread) {
      return res.status(404).json({ error: "Thread not found" });
    }

    const result = await pool.query(
      `
      SELECT id, thread_id, sender_id, message, created_at
      FROM chat_messages
      WHERE thread_id = $1
      ORDER BY created_at ASC
      `,
      [threadId]
    );

    res.json({ thread, messages: result.rows });
  } catch (err) {
    console.error("GET MESSAGES ERROR:", err);
    res.status(500).json({ error: "Failed to fetch messages" });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const userId = req.user.id;
    const threadId = parseInt(req.params.threadId, 10);
    const { message } = req.body;

    if (!message || message.trim().isEmpty) {
      return res.status(400).json({ error: "Message is required" });
    }

    const thread = await getThreadForUser(threadId, userId);
    if (!thread) {
      return res.status(404).json({ error: "Thread not found" });
    }

    const result = await pool.query(
      `
      INSERT INTO chat_messages (thread_id, sender_id, message)
      VALUES ($1, $2, $3)
      RETURNING id, thread_id, sender_id, message, created_at
      `,
      [threadId, userId, message.trim()]
    );

    const recipientId =
      thread.organiser_id === userId
        ? thread.volunteer_id
        : thread.organiser_id;

    try {
      await notifyUser(recipientId, {
        title: "New message",
        body: message.trim(),
        data: { type: "chat_message", threadId: String(threadId) },
      });
    } catch (notifyErr) {
      console.error("CHAT NOTIFY ERROR:", notifyErr);
    }

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("SEND MESSAGE ERROR:", err);
    res.status(500).json({ error: "Failed to send message" });
  }
};
