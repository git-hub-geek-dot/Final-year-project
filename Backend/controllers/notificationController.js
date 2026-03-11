const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

exports.registerDeviceToken = async (req, res) => {
  try {
    const { token, platform } = req.body;
    if (!token) {
      return res.status(400).json({ error: "Token is required" });
    }

    const safePlatform = platform || "android";

    await pool.query(
      `
      INSERT INTO device_tokens (user_id, token, platform)
      VALUES ($1, $2, $3)
      ON CONFLICT (token)
      DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform
      `,
      [req.user.id, token, safePlatform]
    );

    res.json({ success: true });
  } catch (err) {
    console.error("REGISTER TOKEN ERROR:", err);
    res.status(500).json({ error: "Failed to register token" });
  }
};

exports.sendTestNotification = async (req, res) => {
  try {
    const { userId, title, body } = req.body;
    if (!userId || !title || !body) {
      return res.status(400).json({
        error: "userId, title, and body are required",
      });
    }

    await notifyUser(userId, {
      title,
      body,
      data: { type: "test" },
    });

    res.json({ success: true });
  } catch (err) {
    console.error("SEND TEST NOTIFICATION ERROR:", err);
    res.status(500).json({ error: "Failed to send notification" });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = Math.max(parseInt(req.query.page || "1", 10), 1);
    const limit = Math.max(parseInt(req.query.limit || "20", 10), 1);
    const offset = (page - 1) * limit;
    const hiddenType = "ongoing_attendance_update";

    const countRes = await pool.query(
      `
      SELECT COUNT(*)
      FROM notifications
      WHERE user_id = $1
        AND COALESCE(data ->> 'type', '') <> $2
      `,
      [userId, hiddenType]
    );
    const total = parseInt(countRes.rows[0].count, 10);
    const totalPages = Math.max(Math.ceil(total / limit), 1);

    const listRes = await pool.query(
      `
      SELECT id, title, body, data, created_at, read_at
      FROM notifications
      WHERE user_id = $1
        AND COALESCE(data ->> 'type', '') <> $4
      ORDER BY created_at DESC
      LIMIT $2 OFFSET $3
      `,
      [userId, limit, offset, hiddenType]
    );

    res.json({
      items: listRes.rows,
      page,
      totalPages,
      total,
    });
  } catch (err) {
    console.error("GET NOTIFICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to fetch notifications" });
  }
};

exports.getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.id;
    const hiddenType = "ongoing_attendance_update";
    const result = await pool.query(
      `
      SELECT COUNT(*)
      FROM notifications
      WHERE user_id = $1
        AND read_at IS NULL
        AND COALESCE(data ->> 'type', '') <> $2
      `,
      [userId, hiddenType]
    );
    const count = parseInt(result.rows[0].count, 10);
    res.json({ unreadCount: count });
  } catch (err) {
    console.error("GET UNREAD COUNT ERROR:", err);
    res.status(500).json({ error: "Failed to fetch unread count" });
  }
};

exports.markNotificationRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const notificationId = parseInt(req.params.id, 10);

    if (!notificationId || Number.isNaN(notificationId)) {
      return res.status(400).json({ error: "Invalid notification id" });
    }

    const result = await pool.query(
      `
      UPDATE notifications
      SET read_at = COALESCE(read_at, NOW())
      WHERE id = $1 AND user_id = $2
      RETURNING id, read_at
      `,
      [notificationId, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Notification not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("MARK NOTIFICATION READ ERROR:", err);
    res.status(500).json({ error: "Failed to mark notification read" });
  }
};

exports.markAllRead = async (req, res) => {
  try {
    const userId = req.user.id;
    await pool.query(
      "UPDATE notifications SET read_at = NOW() WHERE user_id = $1 AND read_at IS NULL",
      [userId]
    );
    res.json({ message: "All notifications marked as read" });
  } catch (err) {
    console.error("MARK ALL READ ERROR:", err);
    res.status(500).json({ error: "Failed to mark all notifications read" });
  }
};

exports.clearNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    await pool.query(
      "DELETE FROM notifications WHERE user_id = $1",
      [userId]
    );
    res.json({ message: "Notifications cleared" });
  } catch (err) {
    console.error("CLEAR NOTIFICATIONS ERROR:", err);
    res.status(500).json({ error: "Failed to clear notifications" });
  }
};
