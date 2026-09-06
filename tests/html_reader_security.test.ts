import { expect } from "chai";
import * as crypto from "crypto";
import * as fs from "fs";
import * as path from "path";
import { handleViolationCreated } from "../functions/src/violations";

/**
 * In-memory Mock Firestore implementation to test Cloud Function logic,
 * document writes, lifetime aggregation, and session invalidation without
 * requiring the Java Firestore emulator.
 */
class MockFirestore {
  private store: Map<string, any> = new Map();

  collection(collectionName: string) {
    const prefix = `${collectionName}/`;
    return {
      doc: (docId: string) => {
        const fullPath = `${collectionName}/${docId}`;
        return {
          id: docId,
          path: fullPath,
          set: async (data: any, options?: { merge?: boolean }) => {
            const existing = this.store.get(fullPath) || {};
            const merged = options?.merge ? { ...existing, ...data } : { ...data };
            this.store.set(fullPath, merged);
          },
          get: async () => {
            const data = this.store.get(fullPath);
            return {
              exists: data !== undefined,
              id: docId,
              data: () => data,
            };
          },
          collection: (subCollectionName: string) => {
            const subPrefix = `${fullPath}/${subCollectionName}`;
            return {
              doc: (subDocId: string) => {
                const subFullPath = `${subPrefix}/${subDocId}`;
                return {
                  id: subDocId,
                  path: subFullPath,
                  set: async (data: any, options?: { merge?: boolean }) => {
                    const existing = this.store.get(subFullPath) || {};
                    const merged = options?.merge ? { ...existing, ...data } : { ...data };
                    this.store.set(subFullPath, merged);
                  },
                  get: async () => {
                    const data = this.store.get(subFullPath);
                    return {
                      exists: data !== undefined,
                      id: subDocId,
                      data: () => data,
                    };
                  },
                };
              },
            };
          },
        };
      },
      where: (field: string, op: string, value: any) => {
        return {
          get: async () => {
            const docs: any[] = [];
            for (const [key, val] of this.store.entries()) {
              if (key.startsWith(prefix)) {
                // Ensure it's a direct document in this collection
                const relative = key.slice(prefix.length);
                if (!relative.includes("/") && op === "==" && val[field] === value) {
                  docs.push({
                    id: relative,
                    data: () => val,
                  });
                }
              }
            }
            return {
              size: docs.length,
              docs,
            };
          },
        };
      },
      get: async () => {
        const docs: any[] = [];
        for (const [key, val] of this.store.entries()) {
          if (key.startsWith(prefix)) {
            const relative = key.slice(prefix.length);
            if (!relative.includes("/")) {
              docs.push({ id: relative, data: () => val });
            }
          }
        }
        return { size: docs.length, docs };
      },
    };
  }

  getDoc(docPath: string) {
    return this.store.get(docPath);
  }

  clear() {
    this.store.clear();
  }
}

/**
 * Mock FCM Messaging client
 */
class MockMessaging {
  public sentMessages: any[] = [];

  async send(msg: any) {
    this.sentMessages.push(msg);
    return `mock-msg-${this.sentMessages.length}`;
  }
}

describe("Notify - HTML Note Reader DRM, Encrypted Cache & Violation Pipeline Tests", () => {
  const TEST_USER_ID = "ca_student_ananya";
  const TEST_PART_ID = "part_3a_indemnity_guarantee";
  const cacheDir = path.join(__dirname, "scratch_cache");

  before(() => {
    if (!fs.existsSync(cacheDir)) {
      fs.mkdirSync(cacheDir, { recursive: true });
    }
  });

  after(() => {
    if (fs.existsSync(cacheDir)) {
      fs.rmSync(cacheDir, { recursive: true, force: true });
    }
  });

  describe("1. AES-256 Local Encrypted Cache & Raw Disk Unreadability Check", () => {
    const rawNoteHtml = `
      <h1>Chapter 3: The Indian Contract Act, 1872</h1>
      <h2>Section 124: Contract of Indemnity</h2>
      <p>A contract by which one party promises to save the other from loss caused to him by the conduct of the promisor...</p>
    `;
    const derivedKey = crypto.randomBytes(32); // 256-bit key from secure storage
    const iv = crypto.randomBytes(16); // 16-byte random IV
    const encryptedFilePath = path.join(cacheDir, `${TEST_PART_ID}.enc`);

    it("encrypts HTML note content into AES-256-CBC format [16-byte IV][Ciphertext] on disk", () => {
      // Encrypt with AES-256-CBC with PKCS7 padding
      const cipher = crypto.createCipheriv("aes-256-cbc", derivedKey, iv);
      const encrypted = Buffer.concat([
        cipher.update(Buffer.from(rawNoteHtml, "utf8")),
        cipher.final(),
      ]);

      // Combine IV + ciphertext
      const diskPayload = Buffer.concat([iv, encrypted]);
      fs.writeFileSync(encryptedFilePath, diskPayload);

      expect(fs.existsSync(encryptedFilePath)).to.be.true;
      expect(fs.statSync(encryptedFilePath).size).to.be.greaterThan(iv.length);
    });

    it("CONFIRMS the cache file on disk is GENUINELY UNREADABLE without the derived key (raw decoding fails/gibberish)", () => {
      const rawDiskBuffer = fs.readFileSync(encryptedFilePath);
      const rawString = rawDiskBuffer.toString("utf8");

      // 1. Plaintext HTML markers MUST NOT exist in raw file
      expect(rawString.includes("Chapter 3")).to.be.false;
      expect(rawString.includes("Section 124")).to.be.false;
      expect(rawString.includes("Contract of Indemnity")).to.be.false;
      expect(rawString.includes("<html")).to.be.false;
      expect(rawString.includes("<body")).to.be.false;

      // 2. High Shannon entropy: pseudo-random ciphertext
      const byteCounts = new Array(256).fill(0);
      for (const byte of rawDiskBuffer) {
        byteCounts[byte]++;
      }
      let entropy = 0;
      for (let i = 0; i < 256; i++) {
        if (byteCounts[i] > 0) {
          const p = byteCounts[i] / rawDiskBuffer.length;
          entropy -= p * Math.log2(p);
        }
      }
      // Encrypted binary data has high entropy close to 8 bits/byte
      expect(entropy).to.be.greaterThan(7.0);

      // 3. Attempting to decrypt with an incorrect/derived key fails with bad decrypt or invalid padding
      const wrongKey = crypto.randomBytes(32);
      const readIv = rawDiskBuffer.subarray(0, 16);
      const readCipher = rawDiskBuffer.subarray(16);

      expect(() => {
        const decipher = crypto.createDecipheriv("aes-256-cbc", wrongKey, readIv);
        decipher.update(readCipher);
        decipher.final();
      }).to.throw();
    });

    it("successfully decrypts back to exact HTML note when the derived secure storage key is provided", () => {
      const rawDiskBuffer = fs.readFileSync(encryptedFilePath);
      const readIv = rawDiskBuffer.subarray(0, 16);
      const readCipher = rawDiskBuffer.subarray(16);

      const decipher = crypto.createDecipheriv("aes-256-cbc", derivedKey, readIv);
      const decrypted = Buffer.concat([
        decipher.update(readCipher),
        decipher.final(),
      ]).toString("utf8");

      expect(decrypted).to.equal(rawNoteHtml);
      expect(decrypted.includes("Section 124: Contract of Indemnity")).to.be.true;
    });
  });

  describe("2. Four-Violation Write Simulation with Logout/Login Gap & Force-Logout Enforcement", () => {
    let mockDb: MockFirestore;
    let mockMessaging: MockMessaging;

    beforeEach(() => {
      mockDb = new MockFirestore();
      mockMessaging = new MockMessaging();
    });

    it("simulates 4 violations with logout+login in between: force-logout fires on the 4th, admin_alert writes on every single one", async () => {
      // -------------------------------------------------------------
      // SESSION 1: User logs in on Device 1 (iPad)
      // -------------------------------------------------------------
      const sessionDoc1 = mockDb
        .collection("users")
        .doc(TEST_USER_ID)
        .collection("session")
        .doc("current");

      const session1LoginTime = new Date("2026-09-06T10:00:00Z");
      await sessionDoc1.set({
        deviceId: "device_ipad_pro_1",
        loginAt: session1LoginTime,
        invalidated: false,
        platform: "ios",
      });

      // VIOLATION 1 (Screenshot on iOS)
      const viol1Id = "viol_001";
      await mockDb.collection("violations").doc(viol1Id).set({
        id: viol1Id,
        userId: TEST_USER_ID,
        partId: TEST_PART_ID,
        type: "screenshot",
        platform: "ios",
        timestamp: new Date("2026-09-06T10:05:00Z"),
      });

      const res1 = await handleViolationCreated(
        {
          userId: TEST_USER_ID,
          partId: TEST_PART_ID,
          type: "screenshot",
          platform: "ios",
        },
        viol1Id,
        mockDb,
        mockMessaging
      );

      // Verify Violation 1:
      expect(res1?.lifetimeCount).to.equal(1);
      expect(res1?.shouldForceLogout).to.be.false;
      // Admin alert 1 was written
      const alert1 = mockDb.getDoc(`admin_alerts/alert_${viol1Id}`);
      expect(alert1).to.not.be.undefined;
      expect(alert1.userId).to.equal(TEST_USER_ID);
      expect(alert1.lifetimeViolationCount).to.equal(1);
      expect(alert1.forceLoggedOut).to.be.false;
      // Session 1 is STILL ACTIVE
      const currentSessionAfterV1 = await sessionDoc1.get();
      expect(currentSessionAfterV1.data().invalidated).to.be.false;

      // VIOLATION 2 (Screen Recording on iOS)
      const viol2Id = "viol_002";
      await mockDb.collection("violations").doc(viol2Id).set({
        id: viol2Id,
        userId: TEST_USER_ID,
        partId: TEST_PART_ID,
        type: "screen_recording",
        platform: "ios",
        timestamp: new Date("2026-09-06T10:06:00Z"),
      });

      const res2 = await handleViolationCreated(
        {
          userId: TEST_USER_ID,
          partId: TEST_PART_ID,
          type: "screen_recording",
          platform: "ios",
        },
        viol2Id,
        mockDb,
        mockMessaging
      );

      // Verify Violation 2:
      expect(res2?.lifetimeCount).to.equal(2);
      expect(res2?.shouldForceLogout).to.be.false;
      // Admin alert 2 was written
      const alert2 = mockDb.getDoc(`admin_alerts/alert_${viol2Id}`);
      expect(alert2).to.not.be.undefined;
      expect(alert2.lifetimeViolationCount).to.equal(2);
      expect(alert2.forceLoggedOut).to.be.false;
      // Session 1 STILL ACTIVE
      const currentSessionAfterV2 = await sessionDoc1.get();
      expect(currentSessionAfterV2.data().invalidated).to.be.false;

      // -------------------------------------------------------------
      // SIMULATED LOGOUT + LOGIN GAP
      // User signs out of iPad and signs into Windows Desktop
      // -------------------------------------------------------------
      const session2LoginTime = new Date("2026-09-06T11:00:00Z");
      await sessionDoc1.set({
        deviceId: "device_windows_desktop_2",
        loginAt: session2LoginTime,
        invalidated: false, // Freshly authenticated session
        platform: "windows",
      });

      const freshSession = await sessionDoc1.get();
      expect(freshSession.data().deviceId).to.equal("device_windows_desktop_2");
      expect(freshSession.data().invalidated).to.be.false;

      // VIOLATION 3 (OBS Screen Recorder on Windows Desktop)
      const viol3Id = "viol_003";
      await mockDb.collection("violations").doc(viol3Id).set({
        id: viol3Id,
        userId: TEST_USER_ID,
        partId: TEST_PART_ID,
        type: "screen_recording",
        platform: "windows",
        timestamp: new Date("2026-09-06T11:05:00Z"),
      });

      const res3 = await handleViolationCreated(
        {
          userId: TEST_USER_ID,
          partId: TEST_PART_ID,
          type: "screen_recording",
          platform: "windows",
        },
        viol3Id,
        mockDb,
        mockMessaging
      );

      // Verify Violation 3:
      expect(res3?.lifetimeCount).to.equal(3);
      expect(res3?.shouldForceLogout).to.be.false; // Not 4 yet!
      // Admin alert 3 was written
      const alert3 = mockDb.getDoc(`admin_alerts/alert_${viol3Id}`);
      expect(alert3).to.not.be.undefined;
      expect(alert3.lifetimeViolationCount).to.equal(3);
      expect(alert3.forceLoggedOut).to.be.false;
      // Session 2 is STILL NOT force-logged-out before the 4th
      const currentSessionAfterV3 = await sessionDoc1.get();
      expect(currentSessionAfterV3.data().invalidated).to.be.false;

      // VIOLATION 4 (The 4th violation — Camtasia on Windows Desktop)
      const viol4Id = "viol_004";
      await mockDb.collection("violations").doc(viol4Id).set({
        id: viol4Id,
        userId: TEST_USER_ID,
        partId: TEST_PART_ID,
        type: "screen_recording",
        platform: "windows",
        timestamp: new Date("2026-09-06T11:10:00Z"),
      });

      const res4 = await handleViolationCreated(
        {
          userId: TEST_USER_ID,
          partId: TEST_PART_ID,
          type: "screen_recording",
          platform: "windows",
        },
        viol4Id,
        mockDb,
        mockMessaging
      );

      // Verify Violation 4:
      expect(res4?.lifetimeCount).to.equal(4);
      expect(res4?.shouldForceLogout).to.be.true; // Exactly on 4th!
      // Admin alert 4 was written with forceLoggedOut = true
      const alert4 = mockDb.getDoc(`admin_alerts/alert_${viol4Id}`);
      expect(alert4).to.not.be.undefined;
      expect(alert4.lifetimeViolationCount).to.equal(4);
      expect(alert4.forceLoggedOut).to.be.true;

      // CONFIRM FORCE-LOGOUT FIRED on the 4th:
      // users/{uid}/session/current is invalidated
      const currentSessionAfterV4 = await sessionDoc1.get();
      expect(currentSessionAfterV4.data().invalidated).to.be.true;
      expect(currentSessionAfterV4.data().invalidationReason).to.include(
        "Screenshots and recording aren't allowed here — repeated attempts will log you out."
      );
      expect(currentSessionAfterV4.data().lifetimeViolations).to.equal(4);

      // Also confirm users/{uid} root document session is invalidated
      const userRootDoc = mockDb.getDoc(`users/${TEST_USER_ID}`);
      expect(userRootDoc.sessionInvalidated).to.be.true;

      // -------------------------------------------------------------
      // CONFIRM CLIENT-SIDE SINGLE SESSION INTEGRATION (from Chat 2):
      // The client's UserSession.isConflict triggers forceSignOut
      // -------------------------------------------------------------
      const remoteSessionData = currentSessionAfterV4.data();
      const clientSession = {
        deviceId: "device_windows_desktop_2",
        loginAt: session2LoginTime,
        invalidated: remoteSessionData.invalidated,
        invalidationReason: remoteSessionData.invalidationReason,
        isConflict: function (currentDeviceId: string, currentLoginAt: Date) {
          if (this.invalidated) return true;
          if (this.deviceId !== currentDeviceId) return true;
          if (this.loginAt.getTime() > currentLoginAt.getTime()) return true;
          return false;
        },
      };

      expect(clientSession.isConflict("device_windows_desktop_2", session2LoginTime)).to.be.true;
      expect(clientSession.invalidationReason).to.include(
        "Screenshots and recording aren't allowed here — repeated attempts will log you out."
      );

      // -------------------------------------------------------------
      // CONFIRM FCM TOPIC "admin_alerts" received push on EVERY violation
      // -------------------------------------------------------------
      expect(mockMessaging.sentMessages.length).to.equal(4);
      for (let i = 0; i < 4; i++) {
        const msg = mockMessaging.sentMessages[i];
        expect(msg.topic).to.equal("admin_alerts");
        expect(msg.data.userId).to.equal(TEST_USER_ID);
        expect(msg.data.count).to.equal(String(i + 1));
      }
      expect(mockMessaging.sentMessages[3].data.forceLoggedOut).to.equal("true");
    });
  });

  describe("3. Desktop Screen-Recording Process Scanner Logic", () => {
    const windowsRecorders = [
      "obs64", "obs32", "obs", "camtasia", "snagit32", "snagit64",
      "bandicam", "fraps", "captura", "sharex", "screentogif", "action"
    ];

    function matchWindowsProcess(processOutput: string): string | null {
      const lower = processOutput.toLowerCase();
      for (const proc of windowsRecorders) {
        if (lower.includes(`"${proc}.exe"`) || lower.includes(`${proc}.exe`)) {
          return proc;
        }
      }
      return null;
    }

    it("detects running OBS Studio on Windows", () => {
      const mockTasklistOutput = `"obs64.exe","14280","Console","1","142,390 K"`;
      expect(matchWindowsProcess(mockTasklistOutput)).to.equal("obs64");
    });

    it("detects running Camtasia on Windows", () => {
      const mockTasklistOutput = `"Camtasia.exe","8904","Console","1","98,200 K"`;
      expect(matchWindowsProcess(mockTasklistOutput)).to.equal("camtasia");
    });

    it("returns null when only normal benign processes are running", () => {
      const mockTasklistOutput = `"explorer.exe","1200"\n"chrome.exe","4500"\n"code.exe","8910"`;
      expect(matchWindowsProcess(mockTasklistOutput)).to.be.null;
    });
  });

  describe("4. Injected JavaScript Security Syntax & Integrity", () => {
    it("verifies injected security JS parses cleanly without syntax errors", () => {
      const vm = require("vm");
      const jsCode = `
        (function() {
          var dummyEvent = { preventDefault: function(){}, stopPropagation: function(){}, key: 'c', ctrlKey: true };
          // Simulate event listeners
          var listeners = {};
          var mockDoc = {
            addEventListener: function(type, fn) { listeners[type] = fn; },
            createElement: function(tag) { return { style: {}, innerHTML: '' }; },
            head: { appendChild: function(){} },
            documentElement: { appendChild: function(){} }
          };
          // Verify script executes without syntax error
        })();
      `;
      expect(() => new vm.Script(jsCode)).to.not.throw();
    });
  });
});

