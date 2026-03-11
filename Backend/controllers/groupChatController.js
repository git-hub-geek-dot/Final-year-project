const pool = require("../config/db");
const { notifyUsers } = require("../services/notificationService");

const canAccessEventGroupChat = async ({ eventId, userId, role }) => {
  if (role === "organiser") {
    const organiserEvent = await pool.query(
      "SELECT id, title, organiser_id FROM events WHERE id = $1 AND organiser_id = $2",
      [eventId, userId]
    );
    if (organiserEvent.rowCount > 0) {
      return organiserEvent.rows[0];
    }
  }

  const volunteerEvent = await pool.query(
    `
    SELECT e.id, e.title, e.organiser_id
    FROM events e
    JOIN applications a ON a.event_id = e.id
    WHERE e.id = $1
      AND a.volunteer_id = $2
      AND a.status IN ('approved', 'accepted', 'completed')
    LIMIT 1
    `,
    [eventId, userId]
  );

  if (volunteerEvent.rowCount > 0) {
    return volunteerEvent.rows[0];
  }

  return null;
};

exports.getEventGroupMessages = async (req, res) => {
  try {
    const eventId = parseInt(req.params.eventId, 10);
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!Number.isInteger(eventId) || eventId <= 0) {
      return res.status(400).json({ error: "Invalid event ID" });
    }

    const event = await canAccessEventGroupChat({ eventId, userId, role });
    if (!event) {
      return res.status(403).json({ error: "Not allowed to access this event group chat" });
    }

    const messagesRes = await pool.query(
      `
      SELECT m.id, m.event_id, m.sender_id, m.message, m.created_at, u.name AS sender_name
      FROM event_group_messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.event_id = $1
      ORDER BY m.created_at ASC
      `,
      [eventId]
    );

    res.json({
      event: {
        id: event.id,
        title: event.title,
      },
      messages: messagesRes.rows,
    });
  } catch (err) {
    console.error("GET EVENT GROUP MESSAGES ERROR:", err);
    res.status(500).json({ error: "Failed to fetch group messages" });
  }
};

exports.sendEventGroupMessage = async (req, res) => {
  try {
    const eventId = parseInt(req.params.eventId, 10);
    const userId = req.user?.id;
    const role = req.user?.role;
    const message = (req.body?.message || "").toString().trim();

    if (!Number.isInteger(eventId) || eventId <= 0) {
      return res.status(400).json({ error: "Invalid event ID" });
    }

    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    if (message.length > 1000) {
      return res.status(400).json({ error: "Message too long" });
    }

    const event = await canAccessEventGroupChat({ eventId, userId, role });
    if (!event) {
      return res.status(403).json({ error: "Not allowed to send message in this event group chat" });
    }

    const inserted = await pool.query(
      `
      INSERT INTO event_group_messages (event_id, sender_id, message)
      VALUES ($1, $2, $3)
      RETURNING id, event_id, sender_id, message, created_at
      `,
      [eventId, userId, message]
    );

    const senderNameRes = await pool.query("SELECT name FROM users WHERE id = $1", [
      userId,
    ]);
    const senderName = senderNameRes.rows[0]?.name || "User";

    // Notify approved volunteers and organiser, excluding sender.
    const recipientRes = await pool.query(
      `
      SELECT DISTINCT user_id
      FROM (
        SELECT organiser_id AS user_id
        FROM events
        WHERE id = $1

        UNION

        SELECT volunteer_id AS user_id
        FROM applications
        WHERE event_id = $1
          AND status IN ('approved', 'accepted', 'completed')
      ) participants
      WHERE user_id <> $2
      `,
      [eventId, userId]
    );

    const recipientIds = recipientRes.rows.map((row) => row.user_id).filter(Boolean);

    if (recipientIds.length > 0) {
      try {
        await notifyUsers(recipientIds, {
          title: `Group chat: ${event.title}`,
          body: `${senderName}: ${message}`,
          data: {
            type: "event_group_chat",
            eventId: String(eventId),
          },
        });
      } catch (notifyErr) {
        console.error("EVENT GROUP CHAT NOTIFY ERROR:", notifyErr);
      }
    }

    res.status(201).json({
      ...inserted.rows[0],
      sender_name: senderName,
    });
  } catch (err) {
    console.error("SEND EVENT GROUP MESSAGE ERROR:", err);
    res.status(500).json({ error: "Failed to send group message" });
  }
};
