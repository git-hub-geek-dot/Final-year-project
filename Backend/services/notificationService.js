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

const normalizeFcmData = (data) => {
  if (!data || typeof data !== "object") {
    return {};
  }

  return Object.entries(data).reduce((acc, [key, value]) => {
    if (value === null || value === undefined) {
      return acc;
    }

    if (typeof value === "string") {
      acc[key] = value;
      return acc;
    }

    if (
      typeof value === "number" ||
      typeof value === "boolean" ||
      typeof value === "bigint"
    ) {
      acc[key] = String(value);
      return acc;
    }

    acc[key] = JSON.stringify(value);
    return acc;
  }, {});
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
    data: normalizeFcmData(payload.data),
  });
};

const storeNotifications = async (userIds, payload) => {
  const uniqueIds = [...new Set(userIds.filter(Boolean))];
  if (uniqueIds.length === 0) return;

  const title = (payload?.title || "").toString();
  const body = (payload?.body || "").toString();
  const data = payload?.data || {};

  try {
    await pool.query(
      `
      INSERT INTO notifications (user_id, title, body, data)
      SELECT unnest($1::int[]), $2, $3, $4::jsonb
      `,
      [uniqueIds, title, body, JSON.stringify(data)]
    );
  } catch (err) {
    console.error("STORE NOTIFICATION ERROR:", err);
  }
};

const notifyUser = async (userId, payload) => {
  const ids = [userId];
  await storeNotifications(ids, payload);
  const tokens = await getTokensByUserIds(ids);
  await sendToTokens(tokens, payload);
};

const notifyUsers = async (userIds, payload) => {
  const uniqueIds = [...new Set(userIds.filter(Boolean))];
  await storeNotifications(uniqueIds, payload);
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
