require("dotenv").config();
const express = require("express");
const cors = require("cors");


const app = express();
app.use(cors());
app.use(express.json());


app.use("/api", require("./routes/authRoutes"));
app.use("/api", require("./routes/eventRoutes"));
app.use("/api", require("./routes/applicationRoutes"));
app.use("/api", require("./routes/ratingRoutes"));
app.use("/api/admin", require("./routes/adminRoutes"));




app.get("/", (req, res) => {
  res.json({ message: "API running" });
});

const PORT = process.env.PORT || 4000;
app.listen(4000, () => {
  console.log("Server running");
});


