const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendCallNotification = functions.firestore.document("calls/{callId}")
  .onCreate(async (snap, context) => {
    const call = snap.data();
    const receiverId = call.receiverId;
    const callerId = call.callerId;
    const callId = context.params.callId;

    if (callerId === receiverId) {
      console.log("Skipping notification: caller and receiver are the same");
      return null;
    }

    if (call.callStatus !== "ringing") {
      console.log("Skipping notification: call is not ringing");
      return null;
    }

    try {
      const receiverDoc = await admin.firestore()
        .collection("users")
        .doc(receiverId)
        .get();

      if (!receiverDoc.exists) {
        console.log(`Receiver ${receiverId} does not exist`);
        return null;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData?.fcmToken;

      if (!fcmToken) {
        console.log(`Receiver ${receiverId} has no FCM token`);
        return null;
      }

      console.log(`Sending call notification to receiver ${receiverId}`);

      const callerName = call.callerName || "Someone";

      const fcmMessage = {
        token: fcmToken,
        // Notification block REMOVED to prevent system tray double-alert
        // The App's BackgroundHandler or Foreground Listener will handle the display
        data: {
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          type: "call",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          ttl: 0, // Deliver immediately or drop
        },
        apns: {
          headers: {
            "apns-priority": "10", // High priority
          },
          payload: {
            aps: {
              contentAvailable: true, // Wake up app
            },
          },
        },
      };

      const response = await admin.messaging().send(fcmMessage);
      console.log(`Call notification (Data-Only) sent to ${receiverId}`);
      return response;
    } catch (error) {
      console.error(`Error sending call notification to ${receiverId}:`, error);
      // ... token cleanup ...
      return null;
    }
  });

exports.sendMissedCallNotification = functions.firestore.document("calls/{callId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // Trigger only when status changes to 'missed' or 'time_out'
    if (newData.callStatus === oldData.callStatus) return null;
    if (newData.callStatus !== 'missed' && newData.callStatus !== 'busy') return null;

    const receiverId = newData.receiverId;
    const callerName = newData.callerName || "Someone";

    // Send Notification to Receiver
    try {
      const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
      const fcmToken = receiverDoc.data()?.fcmToken;

      if (!fcmToken) return null;

      const messageBody = newData.callStatus === 'missed'
        ? "You missed a call."
        : "You missed a call (Busy).";

      const payload = {
        token: fcmToken,
        notification: {
          title: `Missed Call: ${callerName}`,
          body: messageBody,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'orbitalk_calls_v3', // Updated to v3 to match frontend
            priority: 'max',
            sound: 'default'
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      };

      await admin.messaging().send(payload);
      console.log(`Missed call notification sent to ${receiverId}`);
    } catch (e) {
      console.error("Error sending missed call notification:", e);
    }
    return null;
  });

exports.sendMessageNotification = functions.firestore.document("chatRooms/{chatRoomId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const receiverId = message.receiverId;
    const chatRoomId = context.params.chatRoomId;

    if (message.senderId === receiverId) {
      console.log("Skipping notification: sender and receiver are the same");
      return null;
    }

    try {
      const receiverDoc = await admin.firestore()
        .collection("users")
        .doc(receiverId)
        .get();

      if (!receiverDoc.exists) {
        console.log(`Receiver ${receiverId} does not exist`);
        return null;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData?.fcmToken;

      if (!fcmToken) {
        console.log(`Receiver ${receiverId} has no FCM token`);
        return null;
      }

      console.log(`Attempting to send notification to receiver ${receiverId} with token: ${fcmToken.substring(0, 10)}...`);

      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(message.senderId)
        .get();

      const senderData = senderDoc.data();
      const senderName = senderData?.name || "Someone";

      let notificationBody = "";
      let notificationTitle = senderName;

      switch (message.type) {
        case "text":
          notificationBody = message.message || "Sent a message";
          break;
        case "image":
          notificationBody = message.message ? `📷 ${message.message}` : "📷 Sent an image";
          break;
        case "video":
          notificationBody = message.message ? `🎥 ${message.message}` : "🎥 Sent a video";
          break;
        case "document":
          notificationBody = message.message ? `📄 ${message.message}` : "📄 Sent a document";
          break;
        default:
          notificationBody = "Sent an attachment";
      }

      const fcmMessage = {
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          chatRoomId: chatRoomId,
          senderId: message.senderId,
          messageType: message.type || "text",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "chat_messages",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(fcmMessage);
      console.log(`Notification sent successfully to ${receiverId}:`, response);

      return response;
    } catch (error) {
      console.error(`Error sending notification to ${receiverId}:`, error);

      if (error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered") {
        console.log(`Invalid or expired token for receiver ${receiverId}. Removing token from database.`);

        try {
          await admin.firestore()
            .collection("users")
            .doc(receiverId)
            .update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          console.log(`Successfully removed invalid token for receiver ${receiverId}`);
        } catch (updateError) {
          console.error(`Failed to remove invalid token for receiver ${receiverId}:`, updateError);
        }
      }

      return null;
    }
  });
