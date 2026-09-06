import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { Timestamp, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { expect } from "chai";
import * as fs from "fs";
import * as path from "path";

describe("Notify - Firestore Security Rules Unit Tests", () => {
  let testEnv: RulesTestEnvironment;

  const SUBJECT_ID = "ca_inter_law";
  const LESSON_ID = "chapter_3_contract_act";
  const PART_ID = "part_3a_indemnity";

  const ALICE_UID = "alice_student_123";
  const BOB_UID = "bob_student_456";

  before(async () => {
    const rules = fs.readFileSync("firestore.rules", "utf8");

    testEnv = await initializeTestEnvironment({
      projectId: "notify-test-project",
      firestore: {
        rules,
        host: "127.0.0.1",
        port: 8088,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // Seed master catalog and content data using admin/rules-disabled context
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();

      // 1. Seed Subject
      await setDoc(doc(adminDb, `subjects/${SUBJECT_ID}`), {
        id: SUBJECT_ID,
        title: "Corporate and Other Laws",
        category: "CA",
        level: "Inter",
        order: 1,
      });

      // 2. Seed Lesson
      await setDoc(doc(adminDb, `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}`), {
        id: LESSON_ID,
        subjectId: SUBJECT_ID,
        title: "Chapter 3 - The Indian Contract Act, 1872",
        order: 3,
      });

      // 3. Seed Part Public Metadata (does NOT contain fullRef)
      await setDoc(
        doc(adminDb, `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}`),
        {
          id: PART_ID,
          lessonId: LESSON_ID,
          subjectId: SUBJECT_ID,
          title: "Part A: Contract of Indemnity and Guarantee",
          order: 1,
          fileType: "html",
          previewRef: `content/preview/${PART_ID}.html`,
        }
      );

      // 4. Seed Part Protected Content (contains fullRef)
      await setDoc(
        doc(
          adminDb,
          `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
        ),
        {
          fullRef: `content/full/${PART_ID}.html`,
        }
      );

      // 4. Seed Package
      await setDoc(doc(adminDb, `packages/pkg_law_ch3`), {
        id: "pkg_law_ch3",
        title: "Contract Act Bundle",
        packageType: "lesson",
        refs: [PART_ID],
        pricing: { monthly: 49, threeMonths: 129 },
        isActive: true,
      });
    });
  });

  describe("1. Catalog & Packages Access", () => {
    it("allows unauthenticated users to read subjects catalog", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const subjectDoc = doc(unauthDb, `subjects/${SUBJECT_ID}`);
      await assertSucceeds(getDoc(subjectDoc));
    });

    it("allows unauthenticated users to read lessons catalog", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const lessonDoc = doc(unauthDb, `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}`);
      await assertSucceeds(getDoc(lessonDoc));
    });

    it("allows authenticated users to read available packages and pricing", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const packageDoc = doc(aliceDb, `packages/pkg_law_ch3`);
      await assertSucceeds(getDoc(packageDoc));
    });

    it("denies clients from modifying catalog subjects or packages directly", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const packageDoc = doc(aliceDb, `packages/pkg_law_ch3`);
      await assertFails(updateDoc(packageDoc, { pricing: { monthly: 1 } }));
    });

    it("allows unauthenticated users to read parts catalog metadata (title, order, previewRef)", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const partDoc = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}`
      );
      const snap = await assertSucceeds(getDoc(partDoc));
      expect(snap.data()?.title).to.equal("Part A: Contract of Indemnity and Guarantee");
      expect(snap.data()?.previewRef).to.equal(`content/preview/${PART_ID}.html`);
      expect(snap.data()?.fullRef).to.be.undefined;
    });
  });

  describe("2. Protected Content (parts/protected/content) Access Control", () => {
    it("DENIES unauthenticated users from reading protected content containing fullRef", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const protectedDoc = doc(
        unauthDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      await assertFails(getDoc(protectedDoc));
    });

    it("DENIES authenticated users without a purchase from reading protected content", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const protectedDoc = doc(
        aliceDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      await assertFails(getDoc(protectedDoc));
    });

    it("DENIES authenticated users with an EXPIRED purchase from reading protected content", async () => {
      // Seed an expired purchase for Alice
      const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000); // 1 day ago
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          packageId: "pkg_law_ch3",
          status: "expired",
          expiresAt: Timestamp.fromDate(pastDate),
          purchasedAt: Timestamp.fromDate(new Date(Date.now() - 31 * 24 * 60 * 60 * 1000)),
        });
      });

      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const protectedDoc = doc(
        aliceDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      await assertFails(getDoc(protectedDoc));
    });

    it("ALLOWS authenticated users with a VALID, NON-EXPIRED purchase to read protected content", async () => {
      // Seed an active purchase for Alice (expires in 30 days)
      const futureDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          packageId: "pkg_law_ch3",
          status: "active",
          expiresAt: Timestamp.fromDate(futureDate),
          purchasedAt: Timestamp.fromDate(new Date()),
        });
      });

      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const protectedDoc = doc(
        aliceDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      const snap = await assertSucceeds(getDoc(protectedDoc));
      expect(snap.data()?.fullRef).to.equal(`content/full/${PART_ID}.html`);
    });

    it("DENIES user Bob from reading protected content when only Alice purchased it", async () => {
      // Alice has active purchase, Bob has none
      const futureDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          expiresAt: Timestamp.fromDate(futureDate),
        });
      });

      const bobDb = testEnv.authenticatedContext(BOB_UID).firestore();
      const protectedDoc = doc(
        bobDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      await assertFails(getDoc(protectedDoc));
    });

    it("ALLOWS access to protected content when user has purchased parent Lesson package", async () => {
      // Seed lesson-level purchase for Bob
      const futureDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${BOB_UID}_${LESSON_ID}`), {
          userId: BOB_UID,
          lessonId: LESSON_ID,
          expiresAt: Timestamp.fromDate(futureDate),
        });
      });

      const bobDb = testEnv.authenticatedContext(BOB_UID).firestore();
      const protectedDoc = doc(
        bobDb,
        `subjects/${SUBJECT_ID}/lessons/${LESSON_ID}/parts/${PART_ID}/protected/content`
      );
      const snap = await assertSucceeds(getDoc(protectedDoc));
      expect(snap.data()?.fullRef).to.equal(`content/full/${PART_ID}.html`);
    });
  });

  describe("3. Purchases Collection Anti-Tampering Rules", () => {
    it("DENIES clients from creating or writing purchases directly", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const purchaseDoc = doc(aliceDb, `purchases/${ALICE_UID}_${PART_ID}`);
      await assertFails(
        setDoc(purchaseDoc, {
          userId: ALICE_UID,
          partId: PART_ID,
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 1000000)),
        })
      );
    });

    it("DENIES clients from modifying expiresAt directly", async () => {
      // Seed an active purchase
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 100000)),
        });
      });

      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const purchaseDoc = doc(aliceDb, `purchases/${ALICE_UID}_${PART_ID}`);
      await assertFails(
        updateDoc(purchaseDoc, {
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 999999999)),
        })
      );
    });

    it("ALLOWS users to read their own purchase records", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 100000)),
        });
      });

      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const purchaseDoc = doc(aliceDb, `purchases/${ALICE_UID}_${PART_ID}`);
      await assertSucceeds(getDoc(purchaseDoc));
    });

    it("DENIES users from reading another user's purchase records", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, `purchases/${ALICE_UID}_${PART_ID}`), {
          userId: ALICE_UID,
          partId: PART_ID,
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 100000)),
        });
      });

      const bobDb = testEnv.authenticatedContext(BOB_UID).firestore();
      const purchaseDoc = doc(bobDb, `purchases/${ALICE_UID}_${PART_ID}`);
      await assertFails(getDoc(purchaseDoc));
    });
  });

  describe("4. Session, Progress & Violation Security", () => {
    it("ALLOWS a user to update their own session", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const sessionDoc = doc(aliceDb, `users/${ALICE_UID}/session/current`);
      await assertSucceeds(
        setDoc(sessionDoc, {
          deviceId: "device_abc_1",
          loginAt: Timestamp.fromDate(new Date()),
        })
      );
    });

    it("DENIES a user from reading or modifying another user's session", async () => {
      const bobDb = testEnv.authenticatedContext(BOB_UID).firestore();
      const aliceSessionDoc = doc(bobDb, `users/${ALICE_UID}/session/current`);
      await assertFails(getDoc(aliceSessionDoc));
      await assertFails(
        setDoc(aliceSessionDoc, {
          deviceId: "attacker_device",
          loginAt: Timestamp.fromDate(new Date()),
        })
      );
    });

    it("ALLOWS a user to save and read their reading progress", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const progressDoc = doc(aliceDb, `users/${ALICE_UID}/progress/${PART_ID}`);
      await assertSucceeds(
        setDoc(progressDoc, {
          partId: PART_ID,
          scrollY: 1050,
          updatedAt: Timestamp.fromDate(new Date()),
        })
      );
      await assertSucceeds(getDoc(progressDoc));
    });

    it("ALLOWS a user to log a capture violation with valid timestamp", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const violationDoc = doc(aliceDb, "violations/viol_123");
      await assertSucceeds(
        setDoc(violationDoc, {
          userId: ALICE_UID,
          partId: PART_ID,
          type: "screenshot",
          platform: "ios",
          timestamp: Timestamp.fromDate(new Date()),
        })
      );
    });

    it("DENIES a user from reading or tampering with violations", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const violationDoc = doc(aliceDb, "violations/viol_123");
      await assertFails(getDoc(violationDoc));
    });

    it("DENIES any client from reading or writing admin_alerts directly", async () => {
      const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
      const alertDoc = doc(aliceDb, "admin_alerts/alert_1");
      await assertFails(
        setDoc(alertDoc, {
          userId: ALICE_UID,
          sessionViolationCount: 1,
        })
      );
      await assertFails(getDoc(alertDoc));
    });
  });
});
