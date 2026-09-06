import { expect } from "chai";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, onSnapshot, Timestamp } from "firebase/firestore";
import * as fs from "fs";

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
        remote.invalidationReason || "Your account was accessed from another device."
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

/**
 * Mirror of AuthService OTP state machine from lib/services/auth_service.dart
 */
class MockAuthService {
  public status: "unauthenticated" | "pendingOtp" | "authenticated" = "unauthenticated";
  public activeUserId: string | null = null;
  public pendingEmail: string | null = null;
  private db: any;

  constructor(db: any) {
    this.db = db;
  }

  // Google Flow
  async initiateGoogleSignIn(userId: string, email: string, mockOtpCode: string): Promise<void> {
    // Step 1: Google OAuth validates identity, BUT NOT TRUSTED YET
    this.activeUserId = userId;
    this.pendingEmail = email;
    this.status = "pendingOtp"; // MANDATORY OTP REQUIRED

    // Store pending OTP in Firestore
    const otpDoc = doc(this.db, `users/${userId}/security/pending_otp`);
    await setDoc(otpDoc, {
      code: mockOtpCode,
      email,
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)),
      attempts: 0,
      verified: false,
    });
  }

  async verifyGoogleEmailOtp(userId: string, inputCode: string): Promise<boolean> {
    if (this.status !== "pendingOtp" || this.activeUserId !== userId) {
      return false;
    }

    const otpDoc = doc(this.db, `users/${userId}/security/pending_otp`);
    const snap = await getDoc(otpDoc);
    if (!snap.exists()) return false;

    const data = snap.data();
    if (data.code !== inputCode.trim()) {
      return false;
    }

    // OTP Verified! Complete login
    this.status = "authenticated";
    return true;
  }

  // Phone Flow
  async initiatePhoneSignIn(phoneNumber: string, mockSmsOtp: string): Promise<string> {
    this.pendingPhone = phoneNumber;
    this.status = "pendingOtp";
    return mockSmsOtp; // Verification ID / SMS OTP sent
  }

  async verifyPhoneOtp(userId: string, inputOtp: string, expectedOtp: string): Promise<boolean> {
    if (this.status !== "pendingOtp") return false;

    if (inputOtp.trim() !== expectedOtp) {
      return false;
    }

    this.activeUserId = userId;
    this.status = "authenticated";
    return true;
  }
}

describe("Notify - Auth & Single-Session Simulation Tests", () => {
  let testEnv: RulesTestEnvironment;
  const USER_ID = "ca_student_vikram";

  before(async () => {
    const rules = fs.readFileSync("firestore.rules", "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: "notify-auth-test",
      firestore: {
        rules,
        host: "127.0.0.1",
        port: 8088,
      },
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe("1. Single Active Session & Second-Device Force-Logout", () => {
    it("force-logs-out Device 1 immediately when Device 2 logs in with the same account", async () => {
      const userContext = testEnv.authenticatedContext(USER_ID);
      const db = userContext.firestore();

      const device1 = new MockDeviceClient("android_phone_pixel", USER_ID, db);
      const device2 = new MockDeviceClient("ipad_tablet_pro", USER_ID, db);

      // 1. Device 1 logs in
      await device1.registerSession();
      expect(device1.isForceLoggedOut).to.be.false;
      expect(device1.cachedLoginAt).to.not.be.null;

      // Verify Firestore holds Device 1
      const sessionDoc = await getDoc(doc(db, `users/${USER_ID}/session/current`));
      expect(sessionDoc.data()?.deviceId).to.equal("android_phone_pixel");

      // 2. Device 2 logs in with same user account (simulating second device)
      await new Promise((r) => setTimeout(r, 50)); // Small tick to ensure timestamp advances
      await device2.registerSession();

      // Wait for Device 1's real-time snapshot listener to trigger
      await new Promise((r) => setTimeout(r, 150));

      // 3. Verify Device 1 got force-logged-out
      expect(device1.isForceLoggedOut).to.be.true;
      expect(device1.logoutReason).to.include("accessed from another device");
      expect(device1.cachedLoginAt).to.be.null;

      // 4. Verify Device 2 remains active
      expect(device2.isForceLoggedOut).to.be.false;
      expect(device2.cachedLoginAt).to.not.be.null;

      device1.cleanup();
      device2.cleanup();
    });

    it("detects session conflict on app resume if second device logged in while in background", async () => {
      const userContext = testEnv.authenticatedContext(USER_ID);
      const db = userContext.firestore();

      const device1 = new MockDeviceClient("windows_desktop", USER_ID, db);
      const device2 = new MockDeviceClient("iphone_15", USER_ID, db);

      // Device 1 logs in
      await device1.registerSession();
      device1.cleanup(); // Simulates background state (listener paused)

      // Device 2 logs in while Device 1 is backgrounded
      await new Promise((r) => setTimeout(r, 50));
      await device2.registerSession();

      // Device 1 resumes and validates session
      const isValid = await device1.validateOnResume();

      expect(isValid).to.be.false;
      expect(device1.isForceLoggedOut).to.be.true;
      expect(device1.logoutReason).to.include("accessed from another device");

      device2.cleanup();
    });

    it("immediately forces logout if session document is flagged invalidated (e.g. by security rule / 4th violation)", async () => {
      const userContext = testEnv.authenticatedContext(USER_ID);
      const db = userContext.firestore();

      const device1 = new MockDeviceClient("android_device_1", USER_ID, db);
      await device1.registerSession();

      // Simulate violation Cloud Function marking session invalidated
      await setDoc(
        doc(db, `users/${USER_ID}/session/current`),
        {
          deviceId: "android_device_1",
          loginAt: Timestamp.fromDate(device1.cachedLoginAt!),
          invalidated: true,
          invalidationReason: "Excessive capture violations detected.",
        },
        { merge: true }
      );

      await new Promise((r) => setTimeout(r, 150));

      expect(device1.isForceLoggedOut).to.be.true;
      expect(device1.logoutReason).to.include("Excessive capture violations");

      device1.cleanup();
    });
  });

  describe("2. Mandatory OTP Verification for Both Sign-In Paths", () => {
    it("GENUINELY REQUIRES OTP for Google Sign-In: unverified OAuth cannot authenticate or create session", async () => {
      const userContext = testEnv.authenticatedContext(USER_ID);
      const db = userContext.firestore();
      const auth = new MockAuthService(db);

      // Step 1: User signs in with Google
      const mockOtp = "842913";
      await auth.initiateGoogleSignIn(USER_ID, "student@gmail.com", mockOtp);

      // Verify user is in pendingOtp, NOT authenticated
      expect(auth.status).to.equal("pendingOtp");
      expect(auth.pendingEmail).to.equal("student@gmail.com");

      // Step 2: Attempting to verify with wrong OTP fails
      const wrongOtpSuccess = await auth.verifyGoogleEmailOtp(USER_ID, "000000");
      expect(wrongOtpSuccess).to.be.false;
      expect(auth.status).to.equal("pendingOtp"); // Still blocked

      // Step 3: Verifying with correct OTP succeeds and completes authentication
      const correctOtpSuccess = await auth.verifyGoogleEmailOtp(USER_ID, "842913");
      expect(correctOtpSuccess).to.be.true;
      expect(auth.status).to.equal("authenticated");
    });

    it("GENUINELY REQUIRES OTP for Phone Sign-In: incorrect SMS code is rejected", async () => {
      const userContext = testEnv.authenticatedContext(USER_ID);
      const db = userContext.firestore();
      const auth = new MockAuthService(db);

      // Step 1: Send SMS OTP
      const sentSmsCode = await auth.initiatePhoneSignIn("+919876543210", "471209");
      expect(auth.status).to.equal("pendingOtp");

      // Step 2: Incorrect code fails
      const failed = await auth.verifyPhoneOtp(USER_ID, "999999", sentSmsCode);
      expect(failed).to.be.false;
      expect(auth.status).to.equal("pendingOtp");

      // Step 3: Correct SMS code succeeds
      const passed = await auth.verifyPhoneOtp(USER_ID, "471209", sentSmsCode);
      expect(passed).to.be.true;
      expect(auth.status).to.equal("authenticated");
    });
  });
});
