const pool = require("../config/db");
const { admin, initFirebase } = require("../config/firebaseAdmin");

const getTokensByUserIds = async (userIds) => {
  if (!userIds || userIds.length === 0) return [];

  const result = await pool.query(
    "SELECT token FROM device_tokens WHERE user_id = ANY($1)",
    [userIds]
  );

  return result.rows.map((row) => row.token);
};

const sendToTokens = async (tokens, payload) => {
  if (!tokens || tokens.length === 0) return;

  const app = initFirebase();
  if (!app) {
    console.warn("FCM not configured. Skipping push notification.");
    return;
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data || {},
  });
};

const notifyUser = async (userId, payload) => {
  const tokens = await getTokensByUserIds([userId]);
  await sendToTokens(tokens, payload);
};

const notifyUsers = async (userIds, payload) => {
  const uniqueIds = [...new Set(userIds.filter(Boolean))];
  const tokens = await getTokensByUserIds(uniqueIds);
  await sendToTokens(tokens, payload);
};

module.exports = {
  notifyUser,
  notifyUsers,
};
