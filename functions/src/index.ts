import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

export { grantPurchaseAccess } from "./grantAccess";
export {
  checkAndRevokeAccess,
  scheduledRevokeExpiredPurchases,
} from "./revokeAccess";
export { onViolationCreated, handleViolationCreated } from "./violations";
export { getDrmStreamManifest, requestDrmLicense } from "./drmPipeline";
export * from "./types";
