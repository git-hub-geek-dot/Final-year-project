const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");

const JWT_SECRET = "volunteerx_secret_key";

exports.register = async (req, res) => {
  const { name, email, password, role } = req.body;

  const exists = await pool.query(
    "SELECT id FROM users WHERE email=$1",
    [email]
  );
  if (exists.rows.length) {
    return res.status(400).json({ error: "Email already exists" });
  }

  const hashed = await bcrypt.hash(password, 10);

  const user = await pool.query(
    "INSERT INTO users (name,email,password,role) VALUES ($1,$2,$3,$4) RETURNING id,name,email,role",
    [name, email, hashed, role]
  );

  res.json(user.rows[0]);
};

exports.login = async (req, res) => {
  const { email, password } = req.body;

  const user = await pool.query(
    "SELECT * FROM users WHERE email=$1",
    [email]
  );

  if (!user.rows.length)
    return res.status(400).json({ error: "Invalid credentials" });

  const valid = await bcrypt.compare(password, user.rows[0].password);
  if (!valid)
    return res.status(400).json({ error: "Invalid credentials" });

  const token = jwt.sign(
    { id: user.rows[0].id, role: user.rows[0].role },
    JWT_SECRET,
    { expiresIn: "1d" }
  );

  res.json({ token });
};
