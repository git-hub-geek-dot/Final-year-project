let sgMail = null;

const sendgridApiKey = process.env.SENDGRID_API_KEY;
const sendgridFrom = process.env.SENDGRID_FROM || process.env.SENDGRID_FROM_EMAIL || "noreply@volunteerx.com";

console.log('SendGrid API Key loaded:', sendgridApiKey ? 'Yes (' + sendgridApiKey.substring(0, 10) + '...)' : 'No');

if (sendgridApiKey) {
  try {
    sgMail = require("@sendgrid/mail");
    sgMail.setApiKey(sendgridApiKey);
    console.log('SendGrid initialized successfully');
  } catch (err) {
    console.warn("@sendgrid/mail not installed or failed to initialize", err.message || err);
    sgMail = null;
  }
}

const isConfigured = () => !!sgMail;

const sendEmail = async ({ to, subject, text, html, from: overrideFrom }) => {
  if (!sgMail) {
    throw new Error("Email service not configured");
  }

  const msg = {
    to,
    from: overrideFrom || sendgridFrom,
    subject,
    text,
    html,
  };
  return sgMail.send(msg);
};

module.exports = { sendEmail, isConfigured };
