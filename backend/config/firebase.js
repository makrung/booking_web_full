const admin = require('firebase-admin');

// Load service account from environment variable or file
let serviceAccount;

// For production (Railway): use environment variable
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log('✅ Firebase credentials loaded from FIREBASE_SERVICE_ACCOUNT environment variable');
  } catch (e) {
    console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT:', e.message);
    process.exit(1);
  }
}
// For local development: try to load from file
else if (require('fs').existsSync('../serviceAccountKey.json')) {
  serviceAccount = require('../serviceAccountKey.json');
  console.log('✅ Firebase credentials loaded from serviceAccountKey.json file');
}
// Neither available
else {
  console.error('❌ Firebase credentials not found!');
  console.error('Please provide FIREBASE_SERVICE_ACCOUNT environment variable or serviceAccountKey.json file');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://database-project-ca9fc-default-rtdb.asia-southeast1.firebasedatabase.app"
});

module.exports = admin;