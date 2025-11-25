const admin = require('firebase-admin');

// Load service account from file or environment variable
let serviceAccount;

// Try to load from environment variable first (for production)
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (e) {
    console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT environment variable:', e.message);
    // Fallback to file
    serviceAccount = require('../serviceAccountKey.json');
  }
} else {
  // Load from file (for local development)
  serviceAccount = require('../serviceAccountKey.json');
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://database-project-ca9fc-default-rtdb.asia-southeast1.firebasedatabase.app"
});

module.exports = admin;