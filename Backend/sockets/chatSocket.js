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

const ensureActiveUser = async (userId) => {
  const result = await pool.query(
    `SELECT status, suspended_until
     FROM users
     WHERE id = $1`,
    [userId]
  );

  if (result.rowCount === 0) {
    return { ok: false, reason: "Unauthorized" };
  }

  const user = result.rows[0];
  if (user.status !== "active") {
    return { ok: false, reason: "Unauthorized" };
  }

  if (user.suspended_until) {
    const until = new Date(user.suspended_until);
    if (until.getTime() > Date.now()) {
      return { ok: false, reason: "Suspended" };
    }
  }

  return { ok: true };
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
  console.log("[CHAT SOCKET] init");
  io.use(async (socket, next) => {
    try {
      const authToken = socket.handshake.auth?.token;
      const queryTokenRaw = socket.handshake.query?.token;
      const queryToken = Array.isArray(queryTokenRaw)
        ? queryTokenRaw[0]
        : queryTokenRaw;
      const token = authToken || queryToken;
      console.log("[CHAT SOCKET] Auth attempt", {
        socketId: socket.id,
        hasToken: Boolean(token),
      });
      if (!token) {
        console.warn("[CHAT SOCKET] Missing token", { socketId: socket.id });
        return next(new Error("Unauthorized"));
      }
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const status = await ensureActiveUser(decoded.id);
      if (!status.ok) {
        console.warn("[CHAT SOCKET] Inactive user", {
          socketId: socket.id,
          userId: decoded.id,
          reason: status.reason,
        });
        return next(new Error("Unauthorized"));
      }
      socket.user = decoded;
      console.log("[CHAT SOCKET] Auth success", {
        socketId: socket.id,
        userId: decoded.id,
      });
      return next();
    } catch (err) {
      console.warn("[CHAT SOCKET] Auth error", {
        socketId: socket.id,
        message: err?.message,
      });
      return next(new Error("Unauthorized"));
    }
  });

  io.on("connection", (socket) => {
    console.log("[CHAT SOCKET] Connected", {
      socketId: socket.id,
      userId: socket.user?.id,
    });
    socket.on("disconnect", (reason) => {
      console.log("[CHAT SOCKET] Disconnected", {
        socketId: socket.id,
        userId: socket.user?.id,
        reason,
      });
    });
    socket.on("joinThread", async ({ threadId }) => {
      try {
        if (isTokenExpired(socket)) {
          socket.disconnect(true);
          return;
        }

        const userStatus = await ensureActiveUser(socket.user.id);
        if (!userStatus.ok) {
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

    socket.on("sendMessage", async ({ threadId, message, clientMessageId }) => {
      try {
        const safeClientMessageId =
          clientMessageId != null && String(clientMessageId).trim() !== ""
            ? String(clientMessageId).trim()
            : null;

        if (isTokenExpired(socket)) {
          socket.disconnect(true);
          return;
        }

        const text = message ? String(message).trim() : "";
        if (!text) {
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: "Message is empty.",
            });
          }
          return;
        }

        if (text.length > MESSAGE_MAX_LENGTH) {
          const errorMessage = "Message too long. Please shorten it.";
          socket.emit("rateLimited", {
            message: errorMessage,
          });
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: errorMessage,
            });
          }
          return;
        }

        if (!socket.user?.id) {
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: "Unauthorized.",
            });
          }
          return;
        }

        if (isRateLimited(socket.user.id)) {
          const errorMessage = "Too many messages. Please slow down.";
          socket.emit("rateLimited", {
            message: errorMessage,
          });
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: errorMessage,
            });
          }
          return;
        }

        const userStatus = await ensureActiveUser(socket.user.id);
        if (!userStatus.ok) {
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: "Unauthorized.",
            });
          }
          socket.disconnect(true);
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
          if (safeClientMessageId) {
            socket.emit("messageFailed", {
              clientMessageId: safeClientMessageId,
              message: "Thread not found.",
            });
          }
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

        const payload = {
          ...insertResult.rows[0],
          client_message_id: safeClientMessageId,
        };
        io.to(`thread:${threadId}`).emit("newMessage", payload);
        if (safeClientMessageId) {
          socket.emit("messageAck", {
            clientMessageId: safeClientMessageId,
            message: payload,
          });
        }

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
        const safeClientMessageId =
          clientMessageId != null && String(clientMessageId).trim() !== ""
            ? String(clientMessageId).trim()
            : null;
        if (safeClientMessageId) {
          socket.emit("messageFailed", {
            clientMessageId: safeClientMessageId,
            message: "Message not sent. Please try again.",
          });
        }
      }
    });
  });
};

module.exports = { initChatSocket };
