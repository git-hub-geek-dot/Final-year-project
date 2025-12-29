const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/api", require("./routes/authRoutes"));
app.use("/api", require("./routes/eventRoutes"));
app.use("/api", require("./routes/applicationRoutes"));
app.use("/api", require("./routes/ratingRoutes"));
app.use("/api/admin", require("./routes/adminRoutes"));

app.get("/", (req, res) => {
  res.json({ message: "VolunteerX API running" });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log("Server running on port", PORT);
});
