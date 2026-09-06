process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8088";
process.env.GCLOUD_PROJECT = "notify-drm-test";

import { expect } from "chai";
import {
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, Timestamp } from "firebase/firestore";
import * as fs from "fs";
import { verifyUserPartAccess } from "../functions/src/drmPipeline";

describe("Notify - PDF DRM Pipeline & License Enforcement Tests", () => {
  let testEnv: RulesTestEnvironment;
  const USER_ALICE = "alice_ca_inter";
  const USER_BOB = "bob_unpurchased";
  const PART_ID = "part_tax_gst_input_credit";

  before(async () => {
    const rules = fs.readFileSync("firestore.rules", "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: "notify-drm-test",
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

  describe("1. DRM License Purchase Verification", () => {
    it("REFUSES DRM license when user has NO purchase record for the PDF part", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const hasAccess = await verifyUserPartAccess(USER_BOB, PART_ID, context.firestore());
        expect(hasAccess).to.be.false;
      });
    });

    it("REFUSES DRM license when user's purchase has EXPIRED", async () => {
      // Seed expired purchase for Alice
      const pastDate = new Date(Date.now() - 1000 * 60 * 60 * 24); // 1 day ago
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, `purchases/${USER_ALICE}_${PART_ID}`), {
          userId: USER_ALICE,
          partId: PART_ID,
          status: "active",
          expiresAt: Timestamp.fromDate(pastDate),
        });

        const hasAccess = await verifyUserPartAccess(USER_ALICE, PART_ID, db);
        expect(hasAccess).to.be.false;
      });
    });

    it("REFUSES DRM license when purchase status is 'revoked' or 'expired'", async () => {
      const futureDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, `purchases/${USER_ALICE}_${PART_ID}`), {
          userId: USER_ALICE,
          partId: PART_ID,
          status: "expired", // marked expired
          expiresAt: Timestamp.fromDate(futureDate),
        });

        const hasAccess = await verifyUserPartAccess(USER_ALICE, PART_ID, db);
        expect(hasAccess).to.be.false;
      });
    });

    it("GRANTS DRM license when user has an ACTIVE, NON-EXPIRED purchase", async () => {
      const futureDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // 30 days remaining
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, `purchases/${USER_ALICE}_${PART_ID}`), {
          userId: USER_ALICE,
          partId: PART_ID,
          status: "active",
          expiresAt: Timestamp.fromDate(futureDate),
        });

        const hasAccess = await verifyUserPartAccess(USER_ALICE, PART_ID, db);
        expect(hasAccess).to.be.true;
      });
    });

    it("GRANTS DRM license when user purchased a master package covering the part in coveredPartIds", async () => {
      const futureDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 90);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, `purchases/master_order_99812`), {
          userId: USER_ALICE,
          packageId: "pkg_tax_full_subject",
          status: "active",
          expiresAt: Timestamp.fromDate(futureDate),
          coveredPartIds: [PART_ID, "part_income_tax_basics"],
        });

        const hasAccess = await verifyUserPartAccess(USER_ALICE, PART_ID, db);
        expect(hasAccess).to.be.true;
      });
    });
  });

  describe("2. Video-Frame Page Navigation & Seek Arithmetic", () => {
    const totalPages = 45;
    const pageDurationSeconds = 2.0;

    function getTimestampForPage(page: number): number {
      if (page <= 1) return 0.0;
      if (page > totalPages) return (totalPages - 1) * pageDurationSeconds;
      return (page - 1) * pageDurationSeconds;
    }

    function getPageForTimestamp(seconds: number): number {
      const page = Math.floor(seconds / pageDurationSeconds) + 1;
      if (page < 1) return 1;
      if (page > totalPages) return totalPages;
      return page;
    }

    it("correctly maps page numbers to video keyframe timestamps", () => {
      expect(getTimestampForPage(1)).to.equal(0.0);
      expect(getTimestampForPage(2)).to.equal(2.0);
      expect(getTimestampForPage(10)).to.equal(18.0);
      expect(getTimestampForPage(45)).to.equal(88.0);
      expect(getTimestampForPage(100)).to.equal(88.0); // Clamped to last page
    });

    it("correctly maps video playback timestamps back to 1-based page indices", () => {
      expect(getPageForTimestamp(0.0)).to.equal(1);
      expect(getPageForTimestamp(1.9)).to.equal(1);
      expect(getPageForTimestamp(2.0)).to.equal(2);
      expect(getPageForTimestamp(18.5)).to.equal(10);
      expect(getPageForTimestamp(88.0)).to.equal(45);
    });
  });
});
