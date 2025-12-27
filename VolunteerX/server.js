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

/* ================= EVENTS ================= */
app.post("/api/events", authenticateToken, async (req, res) => {
  if (req.user.role !== "organizer")
    return res.status(403).json({ error: "Only organizers can create events" });

  const { title, description, location, event_date } = req.body;
  if (!title || !event_date)
    return res.status(400).json({ error: "Title and date required" });

  const event = await pool.query(
    "INSERT INTO events (organizer_id,title,description,location,event_date) VALUES ($1,$2,$3,$4,$5) RETURNING *",
    [req.user.id, title, description, location, event_date]
  );

  res.json({ message: "Event created", event: event.rows[0] });
});

app.get("/api/events", async (req, res) => {
  const events = await pool.query(
    `SELECT e.*, u.name AS organizer_name
     FROM events e JOIN users u ON e.organizer_id = u.id
     ORDER BY e.event_date ASC`
  );
  res.json(events.rows);
});

/* ================= APPLY ================= */
app.post("/api/events/:id/apply", authenticateToken, async (req, res) => {
  if (req.user.role !== "volunteer")
    return res.status(403).json({ error: "Only volunteers can apply" });

  const eventId = req.params.id;

  const exists = await pool.query(
    "SELECT 1 FROM events WHERE id=$1",
    [eventId]
  );
  if (exists.rows.length === 0)
    return res.status(404).json({ error: "Event not found" });

  const dup = await pool.query(
    "SELECT 1 FROM applications WHERE event_id=$1 AND volunteer_id=$2",
    [eventId, req.user.id]
  );
  if (dup.rows.length > 0)
    return res.status(400).json({ error: "Already applied" });

  const appRow = await pool.query(
    "INSERT INTO applications (event_id, volunteer_id) VALUES ($1,$2) RETURNING *",
    [eventId, req.user.id]
  );

  res.json({ message: "Applied successfully", application: appRow.rows[0] });
});

/* ================= VIEW APPLICANTS ================= */
app.get("/api/events/:id/applicants", authenticateToken, async (req, res) => {
  if (req.user.role !== "organizer")
    return res.status(403).json({ error: "Only organizers allowed" });

  const event = await pool.query(
    "SELECT 1 FROM events WHERE id=$1 AND organizer_id=$2",
    [req.params.id, req.user.id]
  );
  if (event.rows.length === 0)
    return res.status(403).json({ error: "Not your event" });

  const applicants = await pool.query(
    `SELECT a.id, a.status, u.id AS volunteer_id, u.name, u.email
     FROM applications a JOIN users u ON a.volunteer_id = u.id
     WHERE a.event_id=$1`,
    [req.params.id]
  );

  res.json(applicants.rows);
});

/* ================= DECISION ================= */
app.post("/api/applications/:id/decision", authenticateToken, async (req, res) => {
  if (req.user.role !== "organizer")
    return res.status(403).json({ error: "Only organizers allowed" });

  const { decision } = req.body;
  if (!["approve", "reject"].includes(decision))
    return res.status(400).json({ error: "Invalid decision" });

  const appRow = await pool.query(
    `SELECT a.id, e.organizer_id
     FROM applications a JOIN events e ON a.event_id = e.id
     WHERE a.id=$1`,
    [req.params.id]
  );

  if (appRow.rows.length === 0)
    return res.status(404).json({ error: "Application not found" });

  if (appRow.rows[0].organizer_id !== req.user.id)
    return res.status(403).json({ error: "Not your event" });

  const status = decision === "approve" ? "approved" : "rejected";
  await pool.query(
    "UPDATE applications SET status=$1 WHERE id=$2",
    [status, req.params.id]
  );

  res.json({ message: `Application ${status}` });
});

/* ================= MY APPLICATIONS ================= */
app.get("/api/my-applications", authenticateToken, async (req, res) => {
  if (req.user.role !== "volunteer")
    return res.status(403).json({ error: "Only volunteers allowed" });

  const apps = await pool.query(
    `SELECT a.id AS application_id, a.status,
            e.title, e.location, e.event_date,
            u.name AS organizer_name
     FROM applications a
     JOIN events e ON a.event_id = e.id
     JOIN users u ON e.organizer_id = u.id
     WHERE a.volunteer_id=$1
     ORDER BY a.applied_at DESC`,
    [req.user.id]
  );

  res.json(apps.rows);
});

/* ================= RATINGS (STEP 8) ================= */
app.post("/api/ratings", authenticateToken, async (req, res) => {
  try {
    const { event_id, ratee_id, score, comment } = req.body;

    if (!event_id || !ratee_id || !score)
      return res.status(400).json({ error: "Missing required fields" });

    if (score < 1 || score > 5)
      return res.status(400).json({ error: "Score must be between 1 and 5" });

    const validRelation = await pool.query(
      `SELECT 1
       FROM applications a
       JOIN events e ON a.event_id = e.id
       WHERE a.event_id = $1
         AND a.status = 'approved'
         AND (
           (a.volunteer_id = $2 AND e.organizer_id = $3)
           OR
           (a.volunteer_id = $3 AND e.organizer_id = $2)
         )`,
      [event_id, ratee_id, req.user.id]
    );

    if (validRelation.rows.length === 0)
      return res.status(403).json({ error: "Rating not allowed" });

    const alreadyRated = await pool.query(
      "SELECT 1 FROM ratings WHERE event_id=$1 AND rater_id=$2 AND ratee_id=$3",
      [event_id, req.user.id, ratee_id]
    );

    if (alreadyRated.rows.length > 0)
      return res.status(400).json({ error: "Already rated" });

    await pool.query(
      `INSERT INTO ratings (event_id, rater_id, ratee_id, score, comment)
       VALUES ($1,$2,$3,$4,$5)`,
      [event_id, req.user.id, ratee_id, score, comment || null]
    );

    res.json({ message: "Rating submitted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Rating failed" });
  }
});

/* ================= SERVER ================= */
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
