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

const app = express();

app.set("trust proxy", 1);

app.use(cors());
app.use(express.json());

// Images now served from Cloudinary (no local static serving needed)

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
// Chat
app.use("/api", require("./routes/chatRoutes"));

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
});

initChatSocket(io);

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
