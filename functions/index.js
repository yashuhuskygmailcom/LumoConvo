const {initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();

exports.sendMessageNotification = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const senderId = message.senderId;
    if (typeof senderId !== "string" || senderId.length === 0) return;

    const conversationId = event.params.conversationId;
    const conversationSnapshot = await db
      .collection("conversations")
      .doc(conversationId)
      .get();
    if (!conversationSnapshot.exists) return;

    const conversation = conversationSnapshot.data() || {};
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.filter(
          (id) => typeof id === "string" && id !== senderId,
        )
      : [];
    if (memberIds.length === 0) return;

    const profiles = conversation.memberProfiles || {};
    const senderProfile = profiles[senderId] || {};
    const senderName = senderProfile.displayName || "HayChat User";
    const senderPhoto = senderProfile.photoUrl || "";
    const conversationType = conversation.type === "group" ? "group" : "direct";
    const conversationName = conversation.name || "Group chat";
    const rawText = typeof message.text === "string" ? message.text.trim() : "";

    await Promise.all(
      memberIds.map(async (recipientId) => {
        const [messagingSnapshot, settingsSnapshot] = await Promise.all([
          db.doc(`users/${recipientId}/private/messaging`).get(),
          db.doc(`users/${recipientId}/private/settings`).get(),
        ]);
        const settings = settingsSnapshot.data() || {};
        if (settings.notificationsEnabled === false) return;

        const tokens = [
          ...new Set(
            (messagingSnapshot.data()?.tokens || []).filter(
              (token) => typeof token === "string" && token.length > 0,
            ),
          ),
        ].slice(0, 10);
        if (tokens.length === 0) return;

        const showPreview = settings.messagePreviews !== false;
        const playSound = settings.soundsEnabled !== false;
        const title = conversationType === "group"
          ? `${senderName} in ${conversationName}`
          : senderName;
        const body = showPreview && rawText.length > 0
          ? rawText.slice(0, 180)
          : "Sent you a message";

        const response = await getMessaging().sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            conversationId,
            conversationType,
            conversationName,
            senderId,
            senderName,
            senderPhoto,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "haychat_messages",
              ...(playSound ? {sound: "default"} : {}),
            },
          },
          apns: {
            payload: {
              aps: {
                ...(playSound ? {sound: "default"} : {}),
              },
            },
          },
        });

        const invalidTokens = [];
        response.responses.forEach((result, index) => {
          const code = result.error?.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(tokens[index]);
          } else if (!result.success) {
            logger.warn("Failed to send HayChat notification", {
              recipientId,
              code,
            });
          }
        });
        if (invalidTokens.length > 0) {
          await messagingSnapshot.ref.set(
            {
              tokens: FieldValue.arrayRemove(...invalidTokens),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
          );
        }
      }),
    );
  },
);
