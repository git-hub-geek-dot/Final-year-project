require("dotenv").config();
// TEMP DEBUG (remove later): verify Render provides DATABASE_URL
console.log("[TEMP DEBUG] DATABASE_URL present:", Boolean(process.env.DATABASE_URL));
console.log("[TEMP DEBUG] DATABASE_URL value:", process.env.DATABASE_URL);
const express = require("express");
const cors = require("cors");
const path = require("path");

const app = express();

app.use(cors());
app.use(express.json());

// Serve uploaded images
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

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
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
