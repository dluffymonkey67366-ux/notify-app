process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8088";
process.env.GCLOUD_PROJECT = "notify-e2e-test";

import { expect } from "chai";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import * as fs from "fs";
import * as admin from "firebase-admin";

import { processPurchaseGrant } from "../functions/src/grantAccess";
import { processCheckAndRevoke } from "../functions/src/revokeAccess";
import { handleViolationCreated } from "../functions/src/violations";

/**
 * Mirror of UserSession conflict detection logic from lib/models/user_session.dart
 */
class MockUserSession {
  public deviceId: string;
  public loginAt: Date;
  public invalidated: boolean;
  public invalidationReason?: string;

  constructor(
    deviceId: string,
    loginAt: Date,
    invalidated: boolean = false,
    invalidationReason?: string
  ) {
    this.deviceId = deviceId;
    this.loginAt = loginAt;
    this.invalidated = invalidated;
    this.invalidationReason = invalidationReason;
  }

  static fromFirestore(data: any): MockUserSession {
    return new MockUserSession(
      data.deviceId,
      data.loginAt instanceof Timestamp ? data.loginAt.toDate() : new Date(data.loginAt),
      data.invalidated ?? false,
      data.invalidationReason
    );
  }

  isConflict(currentDeviceId: string, currentLoginAt: Date): boolean {
    if (this.invalidated) return true;
    if (this.deviceId !== currentDeviceId) return true;
    if (this.loginAt.getTime() > currentLoginAt.getTime()) return true;
    return false;
  }
}

/**
 * Mirror of SessionManager state machine from lib/services/session_manager.dart
 * Operating with real Firestore emulator client instances
 */
class MockDeviceClient {
  public deviceId: string;
  public userId: string;
  private db: any;
  public cachedLoginAt: Date | null = null;
  public isForceLoggedOut: boolean = false;
  public logoutReason: string | null = null;
  private unsubscribe: (() => void) | null = null;

  constructor(deviceId: string, userId: string, db: any) {
    this.deviceId = deviceId;
    this.userId = userId;
    this.db = db;
  }

  async registerSession(): Promise<void> {
    const now = new Date();
    this.cachedLoginAt = now;
    this.isForceLoggedOut = false;
    this.logoutReason = null;

    const sessionDoc = doc(this.db, `users/${this.userId}/session/current`);
    await setDoc(sessionDoc, {
      deviceId: this.deviceId,
      loginAt: Timestamp.fromDate(now),
      invalidated: false,
    });

    this.startListener();
  }

  startListener(): void {
    if (this.unsubscribe) this.unsubscribe();

    const sessionDoc = doc(this.db, `users/${this.userId}/session/current`);
    this.unsubscribe = onSnapshot(sessionDoc, (snap) => {
      if (!snap.exists() || !this.cachedLoginAt) return;
      const remote = MockUserSession.fromFirestore(snap.data());

      if (remote.isConflict(this.deviceId, this.cachedLoginAt)) {
        this.handleForceSignOut(
          remote.invalidationReason ||
            "Your account was accessed from another device. Notify allows only one active session per account."
        );
      }
    });
  }

  async validateOnResume(): Promise<boolean> {
    const sessionDoc = doc(this.db, `users/${this.userId}/session/current`);
    const snap = await getDoc(sessionDoc);
    if (!snap.exists() || !this.cachedLoginAt) return true;

    const remote = MockUserSession.fromFirestore(snap.data());
    if (remote.isConflict(this.deviceId, this.cachedLoginAt)) {
      this.handleForceSignOut(
        remote.invalidationReason ||
          "Your account was accessed from another device while the app was in the background."
      );
      return false;
    }
    return true;
  }

  handleForceSignOut(reason: string): void {
    this.isForceLoggedOut = true;
    this.logoutReason = reason;
    this.cachedLoginAt = null;
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  cleanup(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }
}

describe("Notify — End-to-End Flow Tests (Firestore Emulator)", () => {
  let testEnv: RulesTestEnvironment;
  let adminApp: admin.app.App;
  let adminDb: admin.firestore.Firestore;

  const PROJECT_ID = "notify-e2e-test";

  before(async () => {
    const rules = fs.readFileSync("firestore.rules", "utf8");

    // Initialize rules test environment against emulator port 8088
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules,
        host: "127.0.0.1",
        port: 8088,
      },
    });

    // Initialize Admin SDK pointing to the same emulator project
    adminApp = admin.apps.some((a) => a?.name === "e2eAdminApp")
      ? admin.app("e2eAdminApp")
      : admin.initializeApp({ projectId: PROJECT_ID }, "e2eAdminApp");

    adminDb = adminApp.firestore();
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
    if (adminApp) {
      await adminApp.delete();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // =========================================================================
  // JOURNEY 1: Purchase → Access Granted → Content Readable → Plan Expires → Access Revoked Automatically
  // =========================================================================
  describe("Journey 1: Purchase → access granted → content readable → plan expires → access revoked automatically", () => {
    const ARJUN_UID = "student_arjun_ca";
    const SUBJECT_ID = "ca_final_law";
    const LESSON_ID = "board_meetings";
    const PART_ID = "part_1_board_frequency";
    const PACKAGE_ID = "pkg_final_law_board_meetings";

    beforeEach(async () => {
      // Seed Subject
      await adminDb.collection("subjects").doc(SUBJECT_ID).set({
        id: SUBJECT_ID,
        title: "Corporate and Economic Laws",
        category: "CA",
        level: "Final",
        order: 1,
      });

      // Seed Lesson
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .set({
          id: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "Chapter 1: Meetings of Board and its Powers",
          order: 1,
        });

      // Seed Part (Public Metadata - does NOT contain fullRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_ID)
        .set({
          id: PART_ID,
          lessonId: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "Section 173: Board Meetings Frequency & Quorum",
          order: 1,
          fileType: "html",
          previewRef: `content/previews/${PART_ID}.html`,
        });

      // Seed Part Protected Content (contains fullRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_ID)
        .collection("protected")
        .doc("content")
        .set({
          fullRef: `content/drm_notes/${PART_ID}_master.enc`,
          drmKeyId: `key_${PART_ID}`,
        });

      // Seed Package Offering
      await adminDb.collection("packages").doc(PACKAGE_ID).set({
        id: PACKAGE_ID,
        title: "Board Meetings Study Module",
        packageType: "part",
        category: "CA",
        level: "Final",
        subjectId: SUBJECT_ID,
        refs: [PART_ID],
        pricing: { monthly: 49 },
        isActive: true,
      });
    });

    it("executes full purchase lifecycle: unpurchased denied -> purchase grants access -> content readable -> expiry revokes access automatically", async () => {
      const arjunClientDb = testEnv.authenticatedContext(ARJUN_UID).firestore();
      const protectedDocRef = doc(
        arjunClientDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );

      // STEP 1: Prior to purchase, Arjun is DENIED access to protected content
      await assertFails(getDoc(protectedDocRef));

      // STEP 2: Arjun purchases monthly access via real backend purchase processor
      const grantResult = await processPurchaseGrant(
        {
          packageId: PACKAGE_ID,
          planDuration: "monthly",
          razorpayPaymentId: "pay_arjun_test_12345",
          razorpayOrderId: "order_arjun_test_98765",
        },
        ARJUN_UID,
        adminDb
      );

      expect(grantResult.success).to.be.true;
      expect(grantResult.purchaseId).to.be.a("string");
      expect(grantResult.coveredPartIds).to.include(PART_ID);

      // Verify purchase records in Firestore emulator
      const masterPurchaseSnap = await adminDb
        .collection("purchases")
        .doc(grantResult.purchaseId)
        .get();
      expect(masterPurchaseSnap.exists).to.be.true;
      expect(masterPurchaseSnap.data()?.status).to.equal("active");

      const partAccessSnap = await adminDb
        .collection("purchases")
        .doc(`${ARJUN_UID}_${PART_ID}`)
        .get();
      expect(partAccessSnap.exists).to.be.true;
      expect(partAccessSnap.data()?.status).to.equal("active");

      // STEP 3: With valid purchase, Arjun CAN read protected content
      const readableSnap = await assertSucceeds(getDoc(protectedDocRef));
      expect(readableSnap.data()?.fullRef).to.equal(`content/drm_notes/${PART_ID}_master.enc`);
      expect(readableSnap.data()?.drmKeyId).to.equal(`key_${PART_ID}`);

      // STEP 4: Plan expires — simulate time passing past expiresAt
      const pastDate = new Date(Date.now() - 3600 * 1000); // 1 hour in past
      await adminDb
        .collection("purchases")
        .doc(`${ARJUN_UID}_${PART_ID}`)
        .update({
          expiresAt: admin.firestore.Timestamp.fromDate(pastDate),
        });

      await adminDb
        .collection("purchases")
        .doc(grantResult.purchaseId)
        .update({
          expiresAt: admin.firestore.Timestamp.fromDate(pastDate),
        });

      // Firestore Security Rule immediately blocks reading protected content because expiresAt <= request.time
      await assertFails(getDoc(protectedDocRef));

      // STEP 5: Automated revocation executes (app open check / scheduled function)
      const revokeResult = await processCheckAndRevoke(ARJUN_UID, adminDb);
      expect(revokeResult.expiredPackages).to.include(PACKAGE_ID);
      expect(revokeResult.revokedCount).to.be.greaterThan(0);

      // Verify that part access record was completely deleted
      const postRevokePartAccess = await adminDb
        .collection("purchases")
        .doc(`${ARJUN_UID}_${PART_ID}`)
        .get();
      expect(postRevokePartAccess.exists).to.be.false;

      // Verify master purchase record is flagged 'expired'
      const postRevokeMasterPurchase = await adminDb
        .collection("purchases")
        .doc(grantResult.purchaseId)
        .get();
      expect(postRevokeMasterPurchase.data()?.status).to.equal("expired");

      // Verify protected content remains completely inaccessible
      await assertFails(getDoc(protectedDocRef));
    });
  });

  // =========================================================================
  // JOURNEY 2: Login on Device A → Login on Device B → Device A Force-Logged-Out with Correct Message
  // =========================================================================
  describe("Journey 2: Login on Device A → login on Device B → Device A is force-logged-out with correct message", () => {
    const RAHUL_UID = "ca_student_rahul";

    it("immediately force-logs-out Device A when Device B registers session, with the exact single-session message", async () => {
      const rahulClientDb = testEnv.authenticatedContext(RAHUL_UID).firestore();

      const deviceA = new MockDeviceClient("android_samsung_s24", RAHUL_UID, rahulClientDb);
      const deviceB = new MockDeviceClient("macbook_pro_m3", RAHUL_UID, rahulClientDb);

      // 1. Device A logs in and registers active session
      await deviceA.registerSession();
      expect(deviceA.isForceLoggedOut).to.be.false;
      expect(deviceA.cachedLoginAt).to.not.be.null;

      // Confirm session document in Firestore emulator
      const sessionDoc = await adminDb
        .collection("users")
        .doc(RAHUL_UID)
        .collection("session")
        .doc("current")
        .get();
      expect(sessionDoc.data()?.deviceId).to.equal("android_samsung_s24");

      // 2. Device B logs in with the same account
      await new Promise((r) => setTimeout(r, 60)); // Ensure timestamp advances
      await deviceB.registerSession();

      // Wait for real-time Firestore listener on Device A to trigger
      await new Promise((r) => setTimeout(r, 200));

      // 3. Confirm Device A is force-logged-out with the exact message
      expect(deviceA.isForceLoggedOut).to.be.true;
      expect(deviceA.logoutReason).to.equal(
        "Your account was accessed from another device. Notify allows only one active session per account."
      );
      expect(deviceA.cachedLoginAt).to.be.null;

      // 4. Confirm Device B remains active
      expect(deviceB.isForceLoggedOut).to.be.false;
      expect(deviceB.cachedLoginAt).to.not.be.null;

      deviceA.cleanup();
      deviceB.cleanup();
    });

    it("detects conflict and force-logs-out with appropriate message when Device A resumes after background login on Device B", async () => {
      const rahulClientDb = testEnv.authenticatedContext(RAHUL_UID).firestore();

      const deviceA = new MockDeviceClient("ipad_air_5", RAHUL_UID, rahulClientDb);
      const deviceB = new MockDeviceClient("pixel_fold", RAHUL_UID, rahulClientDb);

      // Device A registers session and goes to background (unsubscribes listener)
      await deviceA.registerSession();
      deviceA.cleanup();

      // Device B logs in while Device A is in background
      await new Promise((r) => setTimeout(r, 60));
      await deviceB.registerSession();

      // Device A returns to foreground and validates session
      const isValid = await deviceA.validateOnResume();

      expect(isValid).to.be.false;
      expect(deviceA.isForceLoggedOut).to.be.true;
      expect(deviceA.logoutReason).to.include("accessed from another device");

      deviceB.cleanup();
    });
  });

  // =========================================================================
  // JOURNEY 3: 4 Capture Violations Across Two Separate Simulated Login Sessions
  // 4th one force-logs-out, and admin_alerts record exists for all 4, not just the 4th
  // =========================================================================
  describe("Journey 3: 4 capture violations across two separate simulated login sessions", () => {
    const PRIYA_UID = "ca_student_priya";
    const PART_ID = "part_tax_capital_gains";

    it("records admin_alerts for all 4 violations across 2 sessions and force-logs-out on the 4th with exact warning message", async () => {
      const priyaClientDb = testEnv.authenticatedContext(PRIYA_UID).firestore();

      // -------------------------------------------------------------
      // SESSION 1: Priya logs in on Device 1 (iPhone 15)
      // -------------------------------------------------------------
      const device1 = new MockDeviceClient("iphone_15_pro", PRIYA_UID, priyaClientDb);
      await device1.registerSession();
      expect(device1.isForceLoggedOut).to.be.false;

      const mockMessaging = {
        sent: [] as any[],
        send: async (msg: any) => {
          mockMessaging.sent.push(msg);
          return "msg_success";
        },
      };

      // VIOLATION 1 (Session 1 - Screenshot)
      const viol1Id = "viol_priya_001";
      await adminDb.collection("violations").doc(viol1Id).set({
        id: viol1Id,
        userId: PRIYA_UID,
        partId: PART_ID,
        type: "screenshot",
        platform: "ios",
        timestamp: admin.firestore.Timestamp.now(),
      });

      const res1 = await handleViolationCreated(
        {
          userId: PRIYA_UID,
          partId: PART_ID,
          type: "screenshot",
          platform: "ios",
        },
        viol1Id,
        adminDb,
        mockMessaging
      );

      expect(res1?.lifetimeCount).to.equal(1);
      expect(res1?.shouldForceLogout).to.be.false;

      // Verify admin alert 1 was written in Firestore emulator
      const alert1Snap = await adminDb.collection("admin_alerts").doc(`alert_${viol1Id}`).get();
      expect(alert1Snap.exists).to.be.true;
      expect(alert1Snap.data()?.userId).to.equal(PRIYA_UID);
      expect(alert1Snap.data()?.lifetimeViolationCount).to.equal(1);
      expect(alert1Snap.data()?.forceLoggedOut).to.be.false;

      // Device 1 is still active
      expect(device1.isForceLoggedOut).to.be.false;

      // VIOLATION 2 (Session 1 - Screen Recording)
      const viol2Id = "viol_priya_002";
      await adminDb.collection("violations").doc(viol2Id).set({
        id: viol2Id,
        userId: PRIYA_UID,
        partId: PART_ID,
        type: "screen_recording",
        platform: "ios",
        timestamp: admin.firestore.Timestamp.now(),
      });

      const res2 = await handleViolationCreated(
        {
          userId: PRIYA_UID,
          partId: PART_ID,
          type: "screen_recording",
          platform: "ios",
        },
        viol2Id,
        adminDb,
        mockMessaging
      );

      expect(res2?.lifetimeCount).to.equal(2);
      expect(res2?.shouldForceLogout).to.be.false;

      // Verify admin alert 2 was written in Firestore emulator
      const alert2Snap = await adminDb.collection("admin_alerts").doc(`alert_${viol2Id}`).get();
      expect(alert2Snap.exists).to.be.true;
      expect(alert2Snap.data()?.lifetimeViolationCount).to.equal(2);
      expect(alert2Snap.data()?.forceLoggedOut).to.be.false;

      // Device 1 is still active
      expect(device1.isForceLoggedOut).to.be.false;

      // -------------------------------------------------------------
      // LOGOUT & SESSION 2 TRANSITION: Priya switches to Device 2 (Windows PC)
      // -------------------------------------------------------------
      device1.cleanup();

      const device2 = new MockDeviceClient("windows_surface_pc", PRIYA_UID, priyaClientDb);
      await new Promise((r) => setTimeout(r, 60));
      await device2.registerSession();
      expect(device2.isForceLoggedOut).to.be.false;

      // VIOLATION 3 (Session 2 - Screenshot on Windows)
      const viol3Id = "viol_priya_003";
      await adminDb.collection("violations").doc(viol3Id).set({
        id: viol3Id,
        userId: PRIYA_UID,
        partId: PART_ID,
        type: "screenshot",
        platform: "windows",
        timestamp: admin.firestore.Timestamp.now(),
      });

      const res3 = await handleViolationCreated(
        {
          userId: PRIYA_UID,
          partId: PART_ID,
          type: "screenshot",
          platform: "windows",
        },
        viol3Id,
        adminDb,
        mockMessaging
      );

      expect(res3?.lifetimeCount).to.equal(3);
      expect(res3?.shouldForceLogout).to.be.false;

      // Verify admin alert 3 was written in Firestore emulator
      const alert3Snap = await adminDb.collection("admin_alerts").doc(`alert_${viol3Id}`).get();
      expect(alert3Snap.exists).to.be.true;
      expect(alert3Snap.data()?.lifetimeViolationCount).to.equal(3);
      expect(alert3Snap.data()?.forceLoggedOut).to.be.false;

      // Device 2 is still active before the 4th violation
      expect(device2.isForceLoggedOut).to.be.false;

      // VIOLATION 4 (Session 2 - Screen Recording on Windows: THE 4th LIFETIME VIOLATION)
      const viol4Id = "viol_priya_004";
      await adminDb.collection("violations").doc(viol4Id).set({
        id: viol4Id,
        userId: PRIYA_UID,
        partId: PART_ID,
        type: "screen_recording",
        platform: "windows",
        timestamp: admin.firestore.Timestamp.now(),
      });

      const res4 = await handleViolationCreated(
        {
          userId: PRIYA_UID,
          partId: PART_ID,
          type: "screen_recording",
          platform: "windows",
        },
        viol4Id,
        adminDb,
        mockMessaging
      );

      expect(res4?.lifetimeCount).to.equal(4);
      expect(res4?.shouldForceLogout).to.be.true;

      // Verify admin alert 4 was written with forceLoggedOut = true
      const alert4Snap = await adminDb.collection("admin_alerts").doc(`alert_${viol4Id}`).get();
      expect(alert4Snap.exists).to.be.true;
      expect(alert4Snap.data()?.lifetimeViolationCount).to.equal(4);
      expect(alert4Snap.data()?.forceLoggedOut).to.be.true;

      // -------------------------------------------------------------
      // CRITICAL ASSERTION: All 4 distinct admin_alerts records exist in Firestore emulator
      // -------------------------------------------------------------
      const allAlertsSnap = await adminDb
        .collection("admin_alerts")
        .where("userId", "==", PRIYA_UID)
        .get();

      expect(allAlertsSnap.size).to.equal(4);

      const alertIds = allAlertsSnap.docs.map((d) => d.id);
      expect(alertIds).to.include("alert_viol_priya_001");
      expect(alertIds).to.include("alert_viol_priya_002");
      expect(alertIds).to.include("alert_viol_priya_003");
      expect(alertIds).to.include("alert_viol_priya_004");

      // Verify session document in Firestore emulator is invalidated
      const invalidatedSessionSnap = await adminDb
        .collection("users")
        .doc(PRIYA_UID)
        .collection("session")
        .doc("current")
        .get();

      expect(invalidatedSessionSnap.data()?.invalidated).to.be.true;
      expect(invalidatedSessionSnap.data()?.invalidationReason).to.equal(
        "Screenshots and recording aren't allowed here — repeated attempts will log you out."
      );
      expect(invalidatedSessionSnap.data()?.lifetimeViolations).to.equal(4);

      // Verify user root document is marked sessionInvalidated
      const userRootSnap = await adminDb.collection("users").doc(PRIYA_UID).get();
      expect(userRootSnap.data()?.sessionInvalidated).to.be.true;

      // Wait for real-time listener on Device 2 to receive the invalidation update
      await new Promise((r) => setTimeout(r, 200));

      // Confirm Device 2 is force-logged-out with the violation warning message
      expect(device2.isForceLoggedOut).to.be.true;
      expect(device2.logoutReason).to.equal(
        "Screenshots and recording aren't allowed here — repeated attempts will log you out."
      );

      device2.cleanup();
    });
  });

  // =========================================================================
  // JOURNEY 4: Unpurchased User Browses Full Catalog (Subjects → Lessons → Parts)
  // Sees real titles but CANNOT access protected content (Public/Protected split fix verification)
  // =========================================================================
  describe("Journey 4: Unpurchased user browses full catalog and cannot access protected content", () => {
    const SNEHA_UID = "student_sneha_unpurchased";
    const SUBJECT_ID = "ca_inter_audit";
    const LESSON_ID = "standards_on_auditing";
    const PART_HTML_ID = "part_sa_200_html";
    const PART_PDF_ID = "part_sa_210_pdf";

    beforeEach(async () => {
      // Seed Subject
      await adminDb.collection("subjects").doc(SUBJECT_ID).set({
        id: SUBJECT_ID,
        title: "Paper 5: Auditing and Ethics",
        category: "CA",
        level: "Inter",
        order: 5,
      });

      // Seed Lesson
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .set({
          id: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "Chapter 1: Nature, Objective and Scope of Audit",
          order: 1,
        });

      // Seed Part 1: HTML format (Public metadata with real title, previewRef, NO fullRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_HTML_ID)
        .set({
          id: PART_HTML_ID,
          lessonId: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "SA 200: Overall Objectives of the Independent Auditor",
          order: 1,
          fileType: "html",
          previewRef: `content/previews/${PART_HTML_ID}.html`,
        });

      // Seed Part 1 Protected document (contains fullRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_HTML_ID)
        .collection("protected")
        .doc("content")
        .set({
          fullRef: `content/encrypted_notes/${PART_HTML_ID}.enc`,
          drmKeyId: `drm_key_${PART_HTML_ID}`,
        });

      // Seed Part 2: PDF format (Public metadata with real title, previewRef, NO fullRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_PDF_ID)
        .set({
          id: PART_PDF_ID,
          lessonId: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "SA 210: Agreeing the Terms of Audit Engagements",
          order: 2,
          fileType: "pdf",
          previewRef: `content/previews/${PART_PDF_ID}.png`,
        });

      // Seed Part 2 Protected document (contains fullRef & videoFramesRef)
      await adminDb
        .collection("subjects")
        .doc(SUBJECT_ID)
        .collection("lessons")
        .doc(LESSON_ID)
        .collection("parts")
        .doc(PART_PDF_ID)
        .collection("protected")
        .doc("content")
        .set({
          fullRef: `content/drm_pdf/${PART_PDF_ID}.enc`,
          videoFramesRef: `drm/frames/${PART_PDF_ID}.mp4`,
        });
    });

    it("allows unauthenticated user to browse full hierarchy with real titles, but DENIES access to protected content", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      // 1. Unauthenticated user can read subject and see real title
      const subjectDoc = doc(unauthDb, `subjects/${SUBJECT_ID}`);
      const subjectSnap = await assertSucceeds(getDoc(subjectDoc));
      expect(subjectSnap.exists()).to.be.true;
      expect(subjectSnap.data()?.title).to.equal("Paper 5: Auditing and Ethics");

      // 2. Unauthenticated user can read lesson and see real title
      const lessonDoc = doc(unauthDb, `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}`);
      const lessonSnap = await assertSucceeds(getDoc(lessonDoc));
      expect(lessonSnap.exists()).to.be.true;
      expect(lessonSnap.data()?.title).to.equal(
        "Chapter 1: Nature, Objective and Scope of Audit"
      );

      // 3. Unauthenticated user can read Part 1 metadata (title, previewRef)
      const part1Doc = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_HTML_ID}`
      );
      const part1Snap = await assertSucceeds(getDoc(part1Doc));
      expect(part1Snap.exists()).to.be.true;
      expect(part1Snap.data()?.title).to.equal(
        "SA 200: Overall Objectives of the Independent Auditor"
      );
      expect(part1Snap.data()?.previewRef).to.equal(
        `content/previews/${PART_HTML_ID}.html`
      );
      // Public part document MUST NOT leak fullRef
      expect(part1Snap.data()?.fullRef).to.be.undefined;

      // 4. Unauthenticated user can read Part 2 metadata (title, previewRef)
      const part2Doc = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_PDF_ID}`
      );
      const part2Snap = await assertSucceeds(getDoc(part2Doc));
      expect(part2Snap.exists()).to.be.true;
      expect(part2Snap.data()?.title).to.equal(
        "SA 210: Agreeing the Terms of Audit Engagements"
      );
      expect(part2Snap.data()?.fullRef).to.be.undefined;

      // 5. Unauthenticated user is STRICTLY DENIED access to protected content
      const part1Protected = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_HTML_ID}/protected/content`
      );
      await assertFails(getDoc(part1Protected));

      const part2Protected = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_PDF_ID}/protected/content`
      );
      await assertFails(getDoc(part2Protected));
    });

    it("allows authenticated unpurchased user to browse full hierarchy with real titles, but DENIES access to protected content", async () => {
      const snehaDb = testEnv.authenticatedContext(SNEHA_UID).firestore();

      // 1. Authenticated unpurchased student browses subject
      const subjectDoc = doc(snehaDb, `subjects/${SUBJECT_ID}`);
      const subjectSnap = await assertSucceeds(getDoc(subjectDoc));
      expect(subjectSnap.data()?.title).to.equal("Paper 5: Auditing and Ethics");

      // 2. Student browses lesson
      const lessonDoc = doc(snehaDb, `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}`);
      const lessonSnap = await assertSucceeds(getDoc(lessonDoc));
      expect(lessonSnap.data()?.title).to.equal(
        "Chapter 1: Nature, Objective and Scope of Audit"
      );

      // 3. Student browses parts and sees real titles
      const part1Doc = doc(
        snehaDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_HTML_ID}`
      );
      const part1Snap = await assertSucceeds(getDoc(part1Doc));
      expect(part1Snap.data()?.title).to.equal(
        "SA 200: Overall Objectives of the Independent Auditor"
      );
      expect(part1Snap.data()?.fullRef).to.be.undefined;

      const part2Doc = doc(
        snehaDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_PDF_ID}`
      );
      const part2Snap = await assertSucceeds(getDoc(part2Doc));
      expect(part2Snap.data()?.title).to.equal(
        "SA 210: Agreeing the Terms of Audit Engagements"
      );
      expect(part2Snap.data()?.fullRef).to.be.undefined;

      // 4. Access to protected content is strictly DENIED
      const part1Protected = doc(
        snehaDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_HTML_ID}/protected/content`
      );
      await assertFails(getDoc(part1Protected));

      const part2Protected = doc(
        snehaDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_PDF_ID}/protected/content`
      );
      await assertFails(getDoc(part2Protected));

      // 5. Anti-tampering check: Unpurchased user cannot create, edit or delete catalog items
      await assertFails(
        updateDoc(part1Doc, {
          title: "Tampered Title by Sneha",
        })
      );

      await assertFails(
        setDoc(part1Protected, {
          fullRef: "injected_content_bypass",
        })
      );
    });
  });
});
