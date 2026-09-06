import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Revokes a list of purchase documents by setting status to 'expired'
 * and removing their corresponding part access keys.
 */
async function revokePurchases(purchasesToRevoke: FirebaseFirestore.DocumentSnapshot[]): Promise<string[]> {
  if (purchasesToRevoke.length === 0) return [];

  const batch = db.batch();
  const revokedIds: string[] = [];

  for (const doc of purchasesToRevoke) {
    const data = doc.data();
    if (!data) continue;

    revokedIds.push(doc.id);
    batch.update(doc.ref, {
      status: "expired",
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If master purchase record with coveredPartIds, also invalidate part access docs
    if (Array.isArray(data.coveredPartIds)) {
      for (const partId of data.coveredPartIds) {
        const partRef = db.collection("purchases").doc(`${data.userId}_${partId}`);
        batch.delete(partRef);
      }
    }

    // Also delete direct package reference if present
    if (data.packageId && data.userId) {
      const pkgRef = db.collection("purchases").doc(`${data.userId}_${data.packageId}`);
      batch.delete(pkgRef);
    }
  }

  await batch.commit();
  return revokedIds;
}

/**
 * Cloud Function: checkAndRevokeAccess
 * Callable on app open. Inspects the user's active purchases against current time.
 * If expiresAt has passed -> revokes access records in Firestore and returns expired package IDs
 * so the client can immediately delete that package's local encrypted cache.
 */
export const checkAndRevokeAccess = functions.https.onCall(
  async (data: { userId?: string }, context) => {
    const userId = context.auth?.uid || data.userId;
    if (!userId) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required to verify access."
      );
    }

    const now = admin.firestore.Timestamp.now();

    // Query all active purchases for this user
    const purchasesSnap = await db
      .collection("purchases")
      .where("userId", "==", userId)
      .where("status", "==", "active")
      .get();

    const activePackages: string[] = [];
    const expiredPackages: string[] = [];
    const docsToRevoke: FirebaseFirestore.DocumentSnapshot[] = [];

    purchasesSnap.forEach((doc) => {
      const p = doc.data();
      if (p.expiresAt && p.expiresAt.toMillis() <= now.toMillis()) {
        docsToRevoke.push(doc);
        if (p.packageId && !expiredPackages.includes(p.packageId)) {
          expiredPackages.push(p.packageId);
        }
      } else if (p.packageId && !activePackages.includes(p.packageId)) {
        activePackages.push(p.packageId);
      }
    });

    if (docsToRevoke.length > 0) {
      await revokePurchases(docsToRevoke);
    }

    return {
      userId,
      activePackages,
      expiredPackages,
      revokedCount: docsToRevoke.length,
      verifiedAt: now.toDate().toISOString(),
    };
  }
);

/**
 * Cloud Function: scheduledRevokeExpiredPurchases
 * Runs on schedule (hourly cron) to proactively scan and revoke expired purchases.
 */
export const scheduledRevokeExpiredPurchases = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (_context) => {
    const now = admin.firestore.Timestamp.now();

    const expiredSnap = await db
      .collection("purchases")
      .where("status", "==", "active")
      .where("expiresAt", "<=", now)
      .limit(500)
      .get();

    if (expiredSnap.empty) {
      console.log("No expired purchases to revoke.");
      return null;
    }

    console.log(`Found ${expiredSnap.size} expired purchases to revoke.`);
    const revoked = await revokePurchases(expiredSnap.docs);
    console.log(`Successfully revoked ${revoked.length} purchase records.`);
    return null;
  });
