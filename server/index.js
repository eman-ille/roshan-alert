const admin = require("firebase-admin");
const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(express.json());

const PROJECT_ID = "roshan-alert";

function initFirebase() {
  // 1. Check environment variable first (Production / Render deployment)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      let rawEnv = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
      if ((rawEnv.startsWith("'") && rawEnv.endsWith("'")) || (rawEnv.startsWith('"') && rawEnv.endsWith('"'))) {
        rawEnv = rawEnv.slice(1, -1);
      }
      const serviceAccount = JSON.parse(rawEnv);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: PROJECT_ID,
      });
      console.log("⚡ Firebase Admin initialized with process.env.FIREBASE_SERVICE_ACCOUNT");
      return true;
    } catch (e) {
      console.error("Failed parsing FIREBASE_SERVICE_ACCOUNT env var:", e.message);
    }
  }

  // 2. Check local serviceAccountKey.json
  const serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");
  if (fs.existsSync(serviceAccountPath)) {
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: PROJECT_ID,
      });
      console.log("⚡ Firebase Admin initialized with serviceAccountKey.json");
      return true;
    } catch (e) {
      console.error("Failed loading serviceAccountKey.json:", e.message);
    }
  }

  console.error("ERROR: No credentials found! Place serviceAccountKey.json in server/ or set FIREBASE_SERVICE_ACCOUNT.");
  return false;
}

if (!initFirebase()) {
  process.exit(1);
}

const db = admin.firestore();

app.get("/", (req, res) => {
  res.send("⚡ Roshan Alert FCM Push Notification Server is Online & Active!");
});

// 5-second grace period before server startup to ignore old historical reports
const serverStartTimeMs = Date.now() - 5000;
console.log(`📡 Server Active! Listening for new outage reports...`);

db.collection("reports").onSnapshot(
  (snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
      if (change.type === "added") {
        const data = change.doc.data();
        if (!data) return;

        // Extract timestamp or default to now
        let createdAtMs = Date.now();
        if (data.createdAt && typeof data.createdAt.toDate === "function") {
          createdAtMs = data.createdAt.toDate().getTime();
        }

        // Ignore historical reports submitted before server started
        if (createdAtMs < serverStartTimeMs) {
          return;
        }

        const sanitize = (str) =>
          (str || "")
            .toLowerCase()
            .trim()
            .replace(/[^a-z0-9]/g, "_")
            .replace(/_+/g, "_")
            .replace(/^_+|_+$/g, "");

        const p = sanitize(data.province || "punjab");
        const c = sanitize(data.city || "lahore");
        const a = sanitize(data.area || "dha_phase_5");
        const u = sanitize(data.utility || "electricity");

        const topic = `ra_${p}_${c}_${a}_${u}`;

        const isOut = data.status === "out";
        const statusText = isOut ? "turned OFF" : "turned ON";
        const emoji = isOut ? "🚨" : "💡";

        const title = `${emoji} Roshan Alert: ${data.utility || "Outage Update"}`;
        const body = `${data.utility || "Electricity"} was reported ${statusText} in ${data.area || "your area"}.`;

        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            reporterUid: data.reporterUid || "",
            utility: data.utility || "Electricity",
            status: data.status || "out",
            area: data.area || "",
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "roshan_alert_channel",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          topic: topic,
        };

        try {
          const response = await admin.messaging().send(message);
          console.log(`[PUSH SUCCESS 📲] Sent to topic "${topic}":`, response);
        } catch (err) {
          console.error(`[PUSH ERROR ❌] Failed sending to topic "${topic}":`, err.message);
        }
      }
    });
  },
  (error) => {
    console.error("Firestore snapshot error:", error);
  }
);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Roshan Alert Notification Server listening on port ${PORT}`);
});
