import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Core violation processor logic:
 * 1. Counts user's LIFETIME violations across all sessions (never resets).
 * 2. Regardless of count, writes admin_alerts/{alertId} record.
 * 3. Regardless of count, pushes to FCM topic "admin_alerts" with userId/partId/type/platform/count.
 * 4. If this is the 4th (or higher) violation: force-logout by invalidating users/{uid}/session/current.
 */
export async function handleViolationCreated(
  violation: {
    userId: string;
    partId?: string;
    type?: string;
    platform?: string;
    timestamp?: any;
  },
  violationId: string,
  dbInstance: any = db,
  messagingInstance: any = admin.apps.length ? admin.messaging() : null
) {
  if (!violation || !violation.userId) return null;

  const { userId, partId, type, platform } = violation;

  // 1. Count lifetime violations for this user across all time (never resets)
  const violationsQuery = await dbInstance
    .collection("violations")
    .where("userId", "==", userId)
    .get();

  const lifetimeCount = violationsQuery.size;
  const shouldForceLogout = lifetimeCount >= 4;

  // 2. Write admin alert record (written on every single violation)
  const alertId = `alert_${violationId}`;
  const alertRef = dbInstance.collection("admin_alerts").doc(alertId);

  const alertRecord = {
    id: alertId,
    userId,
    partId: partId || "unknown",
    type: type || "screenshot",
    platform: platform || "unknown",
    lifetimeViolationCount: lifetimeCount,
    timestamp: violation.timestamp || new Date(),
    forceLoggedOut: shouldForceLogout,
    createdAt: new Date(),
  };

  await alertRef.set(alertRecord);

  // 3. Regardless of count, push to FCM topic "admin_alerts"
  if (messagingInstance && typeof messagingInstance.send === "function") {
    try {
      await messagingInstance.send({
        topic: "admin_alerts",
        notification: {
          title: `Violation Alert: ${String(type || "screenshot").toUpperCase()}`,
          body: `User ${userId} recorded violation #${lifetimeCount} on ${platform}. Force logout: ${shouldForceLogout}`,
        },
        data: {
          alertId: String(alertId),
          userId: String(userId),
          partId: String(partId || "unknown"),
          type: String(type || "screenshot"),
          platform: String(platform || "unknown"),
          count: String(lifetimeCount),
          forceLoggedOut: String(shouldForceLogout),
        },
      });
    } catch (fcmError) {
      console.warn("FCM push warning (topic admin_alerts):", fcmError);
    }
  }

  // 4. On the 4th violation (count >= 4): force-logs-out the user by invalidating users/{uid}/session/current
  if (shouldForceLogout) {
    const sessionRef = dbInstance
      .collection("users")
      .doc(userId)
      .collection("session")
      .doc("current");

    await sessionRef.set(
      {
        invalidated: true,
        invalidationReason:
          "Screenshots and recording aren't allowed here — repeated attempts will log you out.",
        invalidatedAt: new Date(),
        lifetimeViolations: lifetimeCount,
      },
      { merge: true }
    );

    // Also mark root user doc session invalidated
    await dbInstance.collection("users").doc(userId).set(
      {
        sessionInvalidated: true,
        invalidationReason:
          "Screenshots and recording aren't allowed here — repeated attempts will log you out.",
        updatedAt: new Date(),
      },
      { merge: true }
    );
  }

  return {
    alertId,
    lifetimeCount,
    shouldForceLogout,
    alertRecord,
  };
}

/**
 * Cloud Function: onViolationCreated
 * Triggers when a screenshot/recording violation is written to violations/{violationId}.
 */
export const onViolationCreated = functions.firestore
  .document("violations/{violationId}")
  .onCreate(async (snap, context) => {
    const violation = snap.data();
    if (!violation) return;
    await handleViolationCreated(
      violation as any,
      context.params.violationId,
      db,
      admin.messaging()
    );
  });
