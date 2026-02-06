const fs = require("fs");
const admin = require("firebase-admin");

let firebaseApp;

const loadServiceAccount = () => {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    const decoded = Buffer.from(
      process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
      "base64"
    ).toString("utf8");
    return JSON.parse(decoded);
  }

  const servicePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (servicePath && fs.existsSync(servicePath)) {
    const raw = fs.readFileSync(servicePath, "utf8");
    return JSON.parse(raw);
  }

  return null;
};

const initFirebase = () => {
  if (firebaseApp) return firebaseApp;

  const serviceAccount = loadServiceAccount();
  if (!serviceAccount) {
    return null;
  }

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  return firebaseApp;
};

module.exports = { admin, initFirebase };
