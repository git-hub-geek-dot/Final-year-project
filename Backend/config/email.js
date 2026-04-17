let sgMail = null;

const sendgridApiKey = process.env.SENDGRID_API_KEY;
const sendgridFrom =
  process.env.SENDGRID_FROM || process.env.SENDGRID_FROM_EMAIL || "";

if (!sendgridApiKey) {
  console.warn("SENDGRID_API_KEY not set. Email service is disabled.");
}

if (!sendgridFrom) {
  console.warn(
    "SENDGRID_FROM (or SENDGRID_FROM_EMAIL) not set. Email service is disabled."
  );
}

if (sendgridApiKey) {
  try {
    sgMail = require("@sendgrid/mail");
    sgMail.setApiKey(sendgridApiKey);
    console.log("SendGrid initialized successfully");
  } catch (err) {
    console.warn(
      "@sendgrid/mail not installed or failed to initialize",
      err.message || err
    );
    sgMail = null;
  }
}

const isConfigured = () => !!sgMail && !!sendgridFrom;

const getConfigurationStatus = () => ({
  configured: isConfigured(),
  hasApiKey: !!sendgridApiKey,
  hasFromAddress: !!sendgridFrom,
});

const extractSendgridError = (err) => {
  const errors = err?.response?.body?.errors;
  if (Array.isArray(errors) && errors.length > 0) {
    return errors
      .map((entry) => entry?.message)
      .filter(Boolean)
      .join("; ");
  }

  return err?.message || "Unknown email provider error";
};

const sendEmail = async ({ to, subject, text, html, from: overrideFrom }) => {
  if (!isConfigured()) {
    throw new Error(
      "Email service not configured. Set SENDGRID_API_KEY and SENDGRID_FROM."
    );
  }

  const from = overrideFrom || sendgridFrom;

  const msg = {
    to,
    from,
    subject,
    text,
    html,
  };

  try {
    return await sgMail.send(msg);
  } catch (err) {
    throw new Error(`SendGrid error: ${extractSendgridError(err)}`);
  }
};

module.exports = { sendEmail, isConfigured, getConfigurationStatus };
