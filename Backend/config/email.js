const nodemailer = require("nodemailer");

const host = process.env.SMTP_HOST;
const port = Number(process.env.SMTP_PORT || 587);
const secure = process.env.SMTP_SECURE === "true";
const user = process.env.SMTP_USER;
const pass = process.env.SMTP_PASS;

const transporter = nodemailer.createTransport({
  host,
  port,
  secure,
  auth: user && pass ? { user, pass } : undefined,
});

module.exports = transporter;
