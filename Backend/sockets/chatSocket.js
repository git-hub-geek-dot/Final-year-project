const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const { notifyUser } = require("../services/notificationService");

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
        const result = await pool.query(
          `
          SELECT id
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
        if (!message || !message.trim()) {
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
          [threadId, socket.user.id, message.trim()]
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
            body: message.trim(),
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
