const STRIKE_SUSPENSIONS = [
  { threshold: 1, days: 7 },
  { threshold: 2, days: 30 },
];

const BAN_STRIKE_THRESHOLD = 3;

const MAX_STRIKE_REASON_LENGTH = 500;

const applyStrike = async (client, { userId, adminId, reason }) => {
  const trimmedReason = (reason || "").toString().trim();

  if (!trimmedReason) {
    const error = new Error("Strike reason is required");
    error.status = 400;
    throw error;
  }

  if (trimmedReason.length > MAX_STRIKE_REASON_LENGTH) {
    const error = new Error("Strike reason is too long");
    error.status = 400;
    throw error;
  }

  if (!adminId) {
    const error = new Error("Admin or organiser ID is required");
    error.status = 400;
    throw error;
  }

  const userRes = await client.query(
    "SELECT id, role, status FROM users WHERE id = $1",
    [userId]
  );

  if (userRes.rowCount === 0) {
    const error = new Error("User not found");
    error.status = 404;
    throw error;
  }

  if (userRes.rows[0].role === "admin") {
    const error = new Error("Cannot strike admin users");
    error.status = 400;
    throw error;
  }

  await client.query(
    `INSERT INTO user_strikes (user_id, admin_id, reason)
     VALUES ($1, $2, $3)`,
    [userId, adminId, trimmedReason]
  );

  return recalculateUserStrikeState(client, {
    userId,
    reasonForPenalty: trimmedReason,
  });
};

const recalculateUserStrikeState = async (
  client,
  { userId, reasonForPenalty = "Strike policy enforcement" }
) => {
  const countRes = await client.query(
    "SELECT COUNT(*)::int AS count FROM user_strikes WHERE user_id = $1",
    [userId]
  );

  const strikeCount = countRes.rows[0]?.count || 0;
  let action = "none";
  let suspendedUntil = null;
  let status = "active";

  if (strikeCount >= BAN_STRIKE_THRESHOLD) {
    const updateRes = await client.query(
      `UPDATE users
       SET status = 'banned',
           suspended_until = NULL,
           suspension_reason = $2
       WHERE id = $1
       RETURNING status`,
      [userId, reasonForPenalty]
    );
    action = "banned";
    status = updateRes.rows[0]?.status || "banned";
    return { strikeCount, action, suspendedUntil, status };
  }

  const suspensionRule = STRIKE_SUSPENSIONS.find(
    (entry) => entry.threshold === strikeCount
  );

  if (suspensionRule) {
    const until = new Date(
      Date.now() + suspensionRule.days * 24 * 60 * 60 * 1000
    );
    const updateRes = await client.query(
      `UPDATE users
       SET status = 'active',
           suspended_until = $2,
           suspension_reason = $3
       WHERE id = $1
       RETURNING suspended_until, status`,
      [userId, until, reasonForPenalty]
    );
    suspendedUntil = updateRes.rows[0]?.suspended_until || until;
    status = updateRes.rows[0]?.status || "active";
    action = `suspended_${suspensionRule.days}_days`;
    return { strikeCount, action, suspendedUntil, status };
  }

  const userUpdateRes = await client.query(
    `UPDATE users
     SET status = 'active',
         suspended_until = NULL,
         suspension_reason = NULL
     WHERE id = $1
     RETURNING status`,
    [userId]
  );
  status = userUpdateRes.rows[0]?.status || "active";

  return { strikeCount, action, suspendedUntil, status };
};

module.exports = {
  STRIKE_SUSPENSIONS,
  BAN_STRIKE_THRESHOLD,
  MAX_STRIKE_REASON_LENGTH,
  applyStrike,
  recalculateUserStrikeState,
};
