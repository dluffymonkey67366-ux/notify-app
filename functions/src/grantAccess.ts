import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { Package, PlanDuration } from "./types";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Calculates exact expiration timestamp based on chosen plan duration.
 */
export function calculateExpiresAt(startDate: Date, duration: PlanDuration): Date {
  const expires = new Date(startDate.getTime());
  switch (duration) {
    case "monthly":
      expires.setMonth(expires.getMonth() + 1);
      break;
    case "threeMonths":
      expires.setMonth(expires.getMonth() + 3);
      break;
    case "sixMonths":
      expires.setMonth(expires.getMonth() + 6);
      break;
    case "oneYear":
      expires.setFullYear(expires.getFullYear() + 1);
      break;
    default:
      throw new Error(`Invalid plan duration: ${duration}`);
  }
  return expires;
}

/**
 * Resolves all individual part IDs covered by a package.
 * Supports parts, lessons, subjects, or bundles.
 */
export async function resolveCoveredPartIds(pkg: Package): Promise<string[]> {
  const partIds = new Set<string>();

  for (const ref of pkg.refs) {
    if (pkg.packageType === "part") {
      partIds.add(ref);
    } else if (pkg.packageType === "lesson") {
      // Query parts inside this lesson across subjects
      const partsSnap = await db
        .collectionGroup("parts")
        .where("lessonId", "==", ref)
        .get();
      if (!partsSnap.empty) {
        partsSnap.forEach((doc) => partIds.add(doc.id));
      } else {
        // Fallback: if ref itself is direct part id
        partIds.add(ref);
      }
    } else if (pkg.packageType === "subject") {
      // Query all parts in this subject
      const partsSnap = await db
        .collectionGroup("parts")
        .where("subjectId", "==", ref)
        .get();
      if (!partsSnap.empty) {
        partsSnap.forEach((doc) => partIds.add(doc.id));
      } else {
        partIds.add(ref);
      }
    } else {
      // Bundle: ref could be a partId, lessonId, or subjectId
      partIds.add(ref);
    }
  }

  return Array.from(partIds);
}

export interface GrantPurchaseAccessInput {
  packageId: string;
  planDuration: PlanDuration;
  razorpayPaymentId?: string;
  razorpayOrderId?: string;
  razorpaySignature?: string;
  userId?: string; // Optional if called internally or from auth context
}

/**
 * Cloud Function: grantPurchaseAccess
 * Triggered on successful payment or called by authenticated client after payment verification.
 * Writes immutable purchases record with correct server-calculated expiresAt.
 */
export const grantPurchaseAccess = functions.https.onCall(
  async (data: GrantPurchaseAccessInput, context) => {
    const userId = context.auth?.uid || data.userId;
    if (!userId) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to purchase access."
      );
    }

    const { packageId, planDuration } = data;
    if (!packageId || !planDuration) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "packageId and planDuration are required."
      );
    }

    // 1. Fetch package definition
    const packageDoc = await db.collection("packages").doc(packageId).get();
    if (!packageDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        `Package ${packageId} not found.`
      );
    }

    const pkg = { id: packageDoc.id, ...packageDoc.data() } as Package;
    if (!pkg.isActive) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Package ${packageId} is not currently active.`
      );
    }

    // 2. Validate that the package actually offers this duration
    const price = pkg.pricing[planDuration];
    if (price === undefined || price === null) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Plan duration ${planDuration} is not offered for package ${packageId}.`
      );
    }

    // 3. Compute server-side timestamps
    const now = new Date();
    const purchasedAt = admin.firestore.Timestamp.fromDate(now);
    const expiresDate = calculateExpiresAt(now, planDuration);
    const expiresAt = admin.firestore.Timestamp.fromDate(expiresDate);

    // 4. Resolve all covered part IDs
    const coveredPartIds = await resolveCoveredPartIds(pkg);

    // 5. Batch write purchase record and part-level access records
    const batch = db.batch();
    const purchaseId = `purch_${userId}_${packageId}_${now.getTime()}`;
    const purchaseRef = db.collection("purchases").doc(purchaseId);

    const masterPurchaseData = {
      id: purchaseId,
      userId,
      packageId,
      packageType: pkg.packageType,
      planDuration,
      purchasedAt,
      expiresAt,
      status: "active",
      amount: price,
      currency: "INR",
      razorpayPaymentId: data.razorpayPaymentId || null,
      razorpayOrderId: data.razorpayOrderId || null,
      coveredPartIds,
      createdAt: purchasedAt,
      updatedAt: purchasedAt,
    };
    batch.set(purchaseRef, masterPurchaseData);

    // Write deterministic part-level purchase documents for O(1) Firestore security rules
    for (const partId of coveredPartIds) {
      const partAccessRef = db.collection("purchases").doc(`${userId}_${partId}`);
      batch.set(
        partAccessRef,
        {
          userId,
          packageId,
          partId,
          packageType: pkg.packageType,
          planDuration,
          purchasedAt,
          expiresAt,
          status: "active",
          masterPurchaseId: purchaseId,
          updatedAt: purchasedAt,
        },
        { merge: true }
      );
    }

    // Also write package level access record
    const pkgAccessRef = db.collection("purchases").doc(`${userId}_${packageId}`);
    batch.set(
      pkgAccessRef,
      {
        userId,
        packageId,
        packageType: pkg.packageType,
        planDuration,
        purchasedAt,
        expiresAt,
        status: "active",
        masterPurchaseId: purchaseId,
        updatedAt: purchasedAt,
      },
      { merge: true }
    );

    await batch.commit();

    return {
      success: true,
      purchaseId,
      expiresAt: expiresAt.toDate().toISOString(),
      coveredPartIds,
    };
  }
);
