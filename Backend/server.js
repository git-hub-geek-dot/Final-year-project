const { applyProcessTimezone } = require("./config/timezone");

applyProcessTimezone();
require("dotenv").config();
// TEMP DEBUG (remove later): verify Render provides DATABASE_URL
console.log("[TEMP DEBUG] DATABASE_URL present:", Boolean(process.env.DATABASE_URL));
console.log("[TEMP DEBUG] DATABASE_URL value:", process.env.DATABASE_URL);
const http = require("http");
const express = require("express");
const cors = require("cors");
const path = require("path");
const { Server } = require("socket.io");
const { initChatSocket } = require("./sockets/chatSocket");
const { markOverdueEventsCompleted } = require("./services/eventStatusService");
const {
  notifyOngoingAttendanceUpdates,
} = require("./services/eventAttendanceNotificationService");

const app = express();

app.set("trust proxy", 1);

app.use(cors());
app.use(express.json());

// Serve local uploads for local testing (when Cloudinary not used)
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ================= ROUTES =================
app.use("/api", require("./routes/authRoutes"));
app.use("/api", require("./routes/eventRoutes"));
app.use("/api", require("./routes/applicationRoutes"));
app.use("/api", require("./routes/ratingRoutes"));
app.use("/api", require("./routes/userRoutes"));
app.use("/api", require("./routes/accountRoutes"));
app.use("/api", require("./routes/profileRoutes"));
// Uploads (images)
app.use("/api", require("./routes/upload"));
// Push notifications
app.use("/api", require("./routes/notificationRoutes"));
// Reports
app.use("/api", require("./routes/reportRoutes"));
// Chat
app.use("/api", require("./routes/chatRoutes"));
app.use("/api", require("./routes/groupChatRoutes"));

// 🔥 ADMIN ROUTES (already correct)
app.use("/api/admin", require("./routes/adminRoutes"));

// 🔥 VERIFICATION ROUTES (FIXED)
app.use("/api/verification", require("./routes/verificationRoutes"));

// ================= HEALTH CHECK =================
app.get("/", (req, res) => {
  res.json({ message: "API running" });
});

// ================= SERVER =================
const PORT = process.env.PORT || 4000;
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
  allowEIO3: true,
});

io.engine.on("connection", (rawSocket) => {
  console.log("[SOCKET.IO] Engine connection", {
    id: rawSocket.id,
    transport: rawSocket.transport?.name,
  });

  let packetCount = 0;
  rawSocket.on("packet", (packet) => {
    if (packetCount < 5) {
      console.log("[SOCKET.IO] Engine packet", {
        id: rawSocket.id,
        type: packet.type,
        data: typeof packet.data === "string" ? packet.data.slice(0, 200) : null,
      });
    }
    packetCount += 1;
  });
});

io.engine.on("connection_error", (err) => {
  console.warn("[SOCKET.IO] Engine connection error", {
    code: err.code,
    message: err.message,
    context: err.context,
  });
});

initChatSocket(io);

const runEventStatusSync = async () => {
  try {
    const [updatedCount, attendanceNotifyCount] = await Promise.all([
      markOverdueEventsCompleted(),
      notifyOngoingAttendanceUpdates(),
    ]);

    if (updatedCount > 0) {
      console.log(
        `[EVENT STATUS] Auto-marked ${updatedCount} overdue event(s) as completed`
      );
    }

    if (attendanceNotifyCount > 0) {
      console.log(
        `[ATTENDANCE NOTIFY] Sent ${attendanceNotifyCount} organiser attendance update notification(s)`
      );
    }
  } catch (err) {
    console.error("[EVENT STATUS] Sync failed:", err);
  }
};

runEventStatusSync();
const eventStatusInterval = setInterval(runEventStatusSync, 5 * 60 * 1000);
if (typeof eventStatusInterval.unref === "function") {
  eventStatusInterval.unref();
}

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
