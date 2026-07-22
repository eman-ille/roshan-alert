const admin = require("firebase-admin");
const express = require("express");
const fs = require("fs");
const path = require("path");
const https = require("https");

const app = express();
app.use(express.json());

const PROJECT_ID = "roshan-alert";

function initFirebase() {
  const serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");
  const configstorePath = "C:/Users/rafay/.config/configstore/firebase-tools.json";

  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: PROJECT_ID,
    });
    console.log("⚡ Firebase Admin initialized with serviceAccountKey.json");
    return true;
  }

  if (fs.existsSync(configstorePath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configstorePath, "utf8"));
      const accessToken = config.tokens?.access_token;
      if (accessToken) {
        admin.initializeApp({
          credential: admin.credential.accessToken(accessToken),
          projectId: PROJECT_ID,
        });
        console.log("⚡ Firebase Admin auto-initialized with Firebase CLI credentials!");
        return true;
      }
    } catch (e) {
      console.warn("Failed loading configstore credentials:", e.message);
    }
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: PROJECT_ID,
    });
    console.log("⚡ Firebase Admin initialized with process.env.FIREBASE_SERVICE_ACCOUNT");
    return true;
  }

  console.error("ERROR: No credentials found! Place serviceAccountKey.json in server/ or login with firebase login.");
  return false;
}

if (!initFirebase()) {
  process.exit(1);
}

const db = admin.firestore();

app.get("/", (req, res) => {
  res.send("⚡ Roshan Alert FCM Push Notification Server is Online & Active!");
});

const serverStartTime = new Date();
console.log(`📡 Server Active! Listening for outage reports created after ${serverStartTime.toISOString()}...`);

db.collection("reports")
  .where("createdAt", ">=", serverStartTime)
  .onSnapshot(
    (snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        if (change.type === "added") {
          const data = change.doc.data();
          if (!data) return;

          const p = (data.province || "punjab").toLowerCase().trim().replace(/\s+/g, "_");
          const c = (data.city || "lahore").toLowerCase().trim().replace(/\s+/g, "_");
          const a = (data.area || "dha_phase_5").toLowerCase().trim().replace(/\s+/g, "_");
          const u = (data.utility || "electricity").toLowerCase().trim().replace(/\s+/g, "_");

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
