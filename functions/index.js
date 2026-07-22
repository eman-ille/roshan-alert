const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggered automatically when any user submits an outage report to Firestore (`reports/{reportId}`).
 * Formats the FCM topic matching the user's area and sends a real-time push notification payload
 * directly to all devices subscribed to that area's topic, waking up closed/killed apps instantly.
 */
exports.onReportCreated = functions.firestore
  .document("reports/{reportId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    // Match exact topic formatting used in Flutter's AlertNotificationService
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
      console.log(`Successfully sent push notification to topic "${topic}":`, response);
      return response;
    } catch (error) {
      console.error(`Error sending push notification to topic "${topic}":`, error);
      return null;
    }
  });
