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

const getAllUserIds = async (roleFilter = null) => {
  let query = "SELECT id FROM users WHERE status = 'active'";
  let params = [];

  if (roleFilter && roleFilter !== 'all') {
    query += " AND role = $1";
    params = [roleFilter];
  }

  const result = await pool.query(query, params);
  return result.rows.map(row => row.id);
};

const broadcastNotification = async (payload, roleFilter = null) => {
  const userIds = await getAllUserIds(roleFilter);
  await notifyUsers(userIds, payload);
};

module.exports = {
  notifyUser,
  notifyUsers,
  broadcastNotification,
  getAllUserIds,
};
