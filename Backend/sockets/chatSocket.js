const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

const MESSAGE_MAX_LENGTH = 1000;
const RATE_WINDOW_MS = 10 * 1000;
const RATE_MAX = 20;
const COOLDOWN_MS = 10 * 1000;
const rateLimits = new Map();

const getRateState = (userId) => {
  if (!rateLimits.has(userId)) {
    rateLimits.set(userId, {
      windowStart: Date.now(),
      count: 0,
      cooldownUntil: 0,
    });
  }
  return rateLimits.get(userId);
};

const isRateLimited = (userId) => {
  const now = Date.now();
  const state = getRateState(userId);

  if (state.cooldownUntil && now < state.cooldownUntil) {
    return true;
  }

  if (now - state.windowStart > RATE_WINDOW_MS) {
    state.windowStart = now;
    state.count = 0;
  }

  if (state.count >= RATE_MAX) {
    state.cooldownUntil = now + COOLDOWN_MS;
    return true;
  }

  state.count += 1;
  return false;
};

const isTokenExpired = (socket) => {
  const exp = socket.user?.exp;
  if (!exp) return false;
  return Date.now() >= exp * 1000;
};

const initChatSocket = (io) => {
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) {
        return next(new Error("Unauthorized"));
      }
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.user = decoded;
      return next();
    } catch (err) {
      return next(new Error("Unauthorized"));
    }
  });

  io.on("connection", (socket) => {
    socket.on("joinThread", async ({ threadId }) => {
      try {
        if (isTokenExpired(socket)) {
          socket.disconnect(true);
          return;
        }

        const result = await pool.query(
          `
          SELECT *
          FROM chat_threads
          WHERE id = $1 AND (organiser_id = $2 OR volunteer_id = $2)
          `,
          [threadId, socket.user.id]
        );

        if (result.rows.length === 0) {
          return;
        }

        socket.join(`thread:${threadId}`);
      } catch (err) {
        console.error("JOIN THREAD ERROR:", err);
      }
    });

    socket.on("sendMessage", async ({ threadId, message }) => {
      try {
        if (isTokenExpired(socket)) {
          socket.disconnect(true);
          return;
        }

        const text = message ? String(message).trim() : "";
        if (!text) {
          return;
        }

        if (text.length > MESSAGE_MAX_LENGTH) {
          socket.emit("rateLimited", {
            message: "Message too long. Please shorten it.",
          });
          return;
        }

        if (!socket.user?.id) {
          return;
        }

        if (isRateLimited(socket.user.id)) {
          socket.emit("rateLimited", {
            message: "Too many messages. Please slow down.",
          });
          return;
        }

        const threadResult = await pool.query(
          `
          SELECT *
          FROM chat_threads
          WHERE id = $1 AND (organiser_id = $2 OR volunteer_id = $2)
          `,
          [threadId, socket.user.id]
        );

        if (threadResult.rows.length === 0) {
          return;
        }

        const thread = threadResult.rows[0];

        const insertResult = await pool.query(
          `
          INSERT INTO chat_messages (thread_id, sender_id, message)
          VALUES ($1, $2, $3)
          RETURNING id, thread_id, sender_id, message, created_at
          `,
          [threadId, socket.user.id, text]
        );

        const payload = insertResult.rows[0];
        io.to(`thread:${threadId}`).emit("newMessage", payload);

        const recipientId =
          thread.organiser_id === socket.user.id
            ? thread.volunteer_id
            : thread.organiser_id;

        try {
          await notifyUser(recipientId, {
            title: "New message",
            body: text,
            data: { type: "chat_message", threadId: String(threadId) },
          });
        } catch (notifyErr) {
          console.error("CHAT SOCKET NOTIFY ERROR:", notifyErr);
        }
      } catch (err) {
        console.error("SEND MESSAGE SOCKET ERROR:", err);
      }
    });
  });
};

module.exports = { initChatSocket };
