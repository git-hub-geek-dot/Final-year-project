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
