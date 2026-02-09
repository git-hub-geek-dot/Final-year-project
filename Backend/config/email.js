const { Resend } = require("resend");
let sgMail = null;

const resendApiKey = process.env.RESEND_API_KEY;
const resendFrom = process.env.RESEND_FROM || "onboarding@resend.dev";

const sendgridApiKey = process.env.SENDGRID_API_KEY;
const sendgridFrom = process.env.SENDGRID_FROM || process.env.SENDGRID_FROM_EMAIL;

const resend = resendApiKey ? new Resend(resendApiKey) : null;
if (sendgridApiKey) {
  try {
    sgMail = require("@sendgrid/mail");
    sgMail.setApiKey(sendgridApiKey);
  } catch (err) {
    console.warn("@sendgrid/mail not installed or failed to initialize", err.message || err);
    sgMail = null;
  }
}

const isConfigured = () => !!(resend || sgMail);

const sendEmail = async ({ to, subject, text, html, from: overrideFrom }) => {
  if (resend) {
    return resend.emails.send({
      from: overrideFrom || resendFrom,
      to,
      subject,
      text,
      html,
    });
  }

  if (sgMail) {
    const msg = {
      to,
      from: overrideFrom || sendgridFrom || resendFrom,
      subject,
      text,
      html,
    };
    return sgMail.send(msg);
  }

  throw new Error("Email service not configured");
};

module.exports = { sendEmail, isConfigured };
