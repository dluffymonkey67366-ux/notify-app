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
export async function revokePurchases(
  purchasesToRevoke: FirebaseFirestore.DocumentSnapshot[],
  dbInstance: any = db
): Promise<string[]> {
  if (purchasesToRevoke.length === 0) return [];

  const batch = dbInstance.batch();
  const revokedIds: string[] = [];
  const deletedDocIds = new Set<string>();
  const now = new Date();

  // First pass: identify all part access and package access docs to delete
  for (const doc of purchasesToRevoke) {
    const data = doc.data();
    if (!data) continue;

    // If master purchase record with coveredPartIds, delete part access docs
    if (Array.isArray(data.coveredPartIds)) {
      for (const partId of data.coveredPartIds) {
        deletedDocIds.add(`${data.userId}_${partId}`);
      }
    }
    // Any derived access key with masterPurchaseId should be deleted
    if (data.masterPurchaseId) {
      deletedDocIds.add(doc.id);
    }
  }

  // Second pass: apply deletes and updates without conflict
  for (const doc of purchasesToRevoke) {
    const data = doc.data();
    if (!data) continue;

    revokedIds.push(doc.id);

    if (deletedDocIds.has(doc.id)) {
      batch.delete(doc.ref);
    } else {
      batch.update(doc.ref, {
        status: "expired",
        revokedAt: now,
        updatedAt: now,
      });
    }
  }

  // Ensure any derived part access docs not directly in purchasesToRevoke are also deleted
  for (const delId of deletedDocIds) {
    if (!purchasesToRevoke.some((d) => d.id === delId)) {
      const delRef = dbInstance.collection("purchases").doc(delId);
      batch.delete(delRef);
    }
  }

  await batch.commit();
  return revokedIds;
}

/**
 * Core check-and-revoke logic.
 */
export async function processCheckAndRevoke(
  userId: string,
  dbInstance: any = db
) {
  const nowMillis = Date.now();

  // Query all active purchases for this user
  const purchasesSnap = await dbInstance
    .collection("purchases")
    .where("userId", "==", userId)
    .where("status", "==", "active")
    .get();

  const activePackages: string[] = [];
  const expiredPackages: string[] = [];
  const docsToRevoke: FirebaseFirestore.DocumentSnapshot[] = [];

  purchasesSnap.forEach((doc: any) => {
    const p = doc.data();
    const expiresMillis = p.expiresAt?.toMillis
      ? p.expiresAt.toMillis()
      : p.expiresAt?.toDate
      ? p.expiresAt.toDate().getTime()
      : p.expiresAt instanceof Date
      ? p.expiresAt.getTime()
      : new Date(p.expiresAt).getTime();

    if (expiresMillis && expiresMillis <= nowMillis) {
      docsToRevoke.push(doc);
      if (p.packageId && !expiredPackages.includes(p.packageId)) {
        expiredPackages.push(p.packageId);
      }
    } else if (p.packageId && !activePackages.includes(p.packageId)) {
      activePackages.push(p.packageId);
    }
  });

  if (docsToRevoke.length > 0) {
    await revokePurchases(docsToRevoke, dbInstance);
  }

  return {
    userId,
    activePackages,
    expiredPackages,
    revokedCount: docsToRevoke.length,
    verifiedAt: new Date(nowMillis).toISOString(),
  };
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

    return processCheckAndRevoke(userId, db);
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
