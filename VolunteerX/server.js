const express = require("express");
const cors = require("cors");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

/* ================= DATABASE ================= */
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

/* ================= JWT ================= */
const JWT_SECRET = process.env.JWT_SECRET || "volunteerx_secret_key";

/* ================= AUTH MIDDLEWARE ================= */
function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) return res.status(401).json({ error: "Token missing" });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: "Invalid token" });
    req.user = user;
    next();
  });
}

/* ================= TEST ROUTE ================= */
app.get("/", (req, res) => {
  res.json({ message: "VolunteerX Auth Ready" });
});

/* ================= REGISTER ================= */
app.post("/api/register", async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ error: "All fields required" });
    }

    const userExists = await pool.query(
      "SELECT id FROM users WHERE email=$1",
      [email]
    );

    if (userExists.rows.length > 0) {
      return res.status(400).json({ error: "Email already registered" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = await pool.query(
      "INSERT INTO users (name, email, password, role) VALUES ($1,$2,$3,$4) RETURNING id,name,email,role",
      [name, email, hashedPassword, role]
    );

    res.json({
      message: "User registered successfully",
      user: newUser.rows[0],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Registration failed" });
  }
});

/* ================= LOGIN ================= */
app.post("/api/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await pool.query(
      "SELECT * FROM users WHERE email=$1",
      [email]
    );

    if (user.rows.length === 0) {
      return res.status(400).json({ error: "Invalid credentials" });
    }

    const validPassword = await bcrypt.compare(
      password,
      user.rows[0].password
    );

    if (!validPassword) {
      return res.status(400).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: user.rows[0].id, role: user.rows[0].role },
      JWT_SECRET,
      { expiresIn: "1d" }
    );

    res.json({
      message: "Login successful",
      token,
      user: {
        id: user.rows[0].id,
        name: user.rows[0].name,
        email: user.rows[0].email,
        role: user.rows[0].role,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Login failed" });
  }
});

/* ================= CREATE EVENT ================= */
app.post("/api/events", authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Only organizers can create events" });
    }

    const { title, description, location, event_date } = req.body;

    if (!title || !event_date) {
      return res.status(400).json({ error: "Title and date required" });
    }

    const newEvent = await pool.query(
      "INSERT INTO events (organizer_id, title, description, location, event_date) VALUES ($1,$2,$3,$4,$5) RETURNING *",
      [req.user.id, title, description, location, event_date]
    );

    res.json({
      message: "Event created successfully",
      event: newEvent.rows[0],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Event creation failed" });
  }
});

/* ================= GET EVENTS ================= */
app.get("/api/events", async (req, res) => {
  try {
    const events = await pool.query(
      `SELECT e.*, u.name AS organizer_name
       FROM events e
       JOIN users u ON e.organizer_id = u.id
       ORDER BY e.event_date ASC`
    );

    res.json(events.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch events" });
  }
});

/* ================= APPLY TO EVENT ================= */
app.post("/api/events/:id/apply", authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== "volunteer") {
      return res.status(403).json({ error: "Only volunteers can apply" });
    }

    const eventId = req.params.id;

    const event = await pool.query(
      "SELECT * FROM events WHERE id=$1",
      [eventId]
    );

    if (event.rows.length === 0) {
      return res.status(404).json({ error: "Event not found" });
    }

    const alreadyApplied = await pool.query(
      "SELECT * FROM applications WHERE event_id=$1 AND volunteer_id=$2",
      [eventId, req.user.id]
    );

    if (alreadyApplied.rows.length > 0) {
      return res.status(400).json({ error: "Already applied to this event" });
    }

    const application = await pool.query(
      "INSERT INTO applications (event_id, volunteer_id) VALUES ($1,$2) RETURNING *",
      [eventId, req.user.id]
    );

    res.json({
      message: "Applied successfully",
      application: application.rows[0],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Application failed" });
  }
});

/* ================= VIEW APPLICANTS ================= */
app.get("/api/events/:id/applicants", authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Only organizers can view applicants" });
    }

    const eventId = req.params.id;

    const event = await pool.query(
      "SELECT * FROM events WHERE id=$1 AND organizer_id=$2",
      [eventId, req.user.id]
    );

    if (event.rows.length === 0) {
      return res.status(403).json({ error: "Not your event" });
    }

    const applicants = await pool.query(
      `SELECT a.id, a.status, u.id AS volunteer_id, u.name, u.email
       FROM applications a
       JOIN users u ON a.volunteer_id = u.id
       WHERE a.event_id = $1`,
      [eventId]
    );

    res.json(applicants.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch applicants" });
  }
});

/* ================= APPROVE / REJECT ================= */
app.post("/api/applications/:id/decision", authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== "organizer") {
      return res.status(403).json({ error: "Only organizers can take decisions" });
    }

    const applicationId = req.params.id;
    const { decision } = req.body;

    if (!["approve", "reject"].includes(decision)) {
      return res.status(400).json({ error: "Invalid decision" });
    }

    const application = await pool.query(
      `SELECT a.*, e.organizer_id
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.id = $1`,
      [applicationId]
    );

    if (application.rows.length === 0) {
      return res.status(404).json({ error: "Application not found" });
    }

    if (application.rows[0].organizer_id !== req.user.id) {
      return res.status(403).json({ error: "Not your event" });
    }

    const newStatus = decision === "approve" ? "approved" : "rejected";

    await pool.query(
      "UPDATE applications SET status=$1 WHERE id=$2",
      [newStatus, applicationId]
    );

    res.json({ message: `Application ${newStatus}` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Decision failed" });
  }
});

/* ================= VOLUNTEER: MY APPLICATIONS ================= */
app.get("/api/my-applications", authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== "volunteer") {
      return res.status(403).json({ error: "Only volunteers can view applications" });
    }

    const applications = await pool.query(
  `SELECT 
     a.id AS application_id,
     a.status,
     e.id AS event_id,
     e.title,
     e.location,
     e.event_date,
     u.name AS organizer_name
   FROM applications a
   JOIN events e ON a.event_id = e.id
   JOIN users u ON e.organizer_id = u.id
   WHERE a.volunteer_id = $1
   ORDER BY a.applied_at DESC`,
  [req.user.id]
);


    res.json(applications.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch applications" });
  }
});

/* ================= SERVER ================= */
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
