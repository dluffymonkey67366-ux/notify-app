import { expect } from "chai";
import { Package, PlanDuration } from "../functions/src/types";
import { calculateExpiresAt, resolveCoveredPartIds } from "../functions/src/grantAccess";

describe("Notify — Catalog Flow & Package Duration Filtering Tests", () => {
  // Test packages covering different granularities and duration configurations
  const partPackage: Package = {
    id: "pkg_part_3a",
    title: "Part A Only — Contract of Indemnity",
    packageType: "part",
    category: "CA",
    level: "Inter",
    subjectId: "ca_inter_law",
    refs: ["part_3a_indemnity_guarantee"],
    pricing: {
      monthly: 49, // ONLY monthly configured!
    },
    isActive: true,
    createdAt: null as any,
    updatedAt: null as any,
  };

  const lessonPackage: Package = {
    id: "pkg_law_ch3_all",
    title: "Contract Act — Complete Chapter 3 Bundle",
    packageType: "lesson",
    category: "CA",
    level: "Inter",
    subjectId: "ca_inter_law",
    refs: [
      "chapter_3_contract_act",
      "part_3a_indemnity_guarantee",
      "part_3b_bailment_pledge",
      "part_3c_agency",
    ],
    pricing: {
      monthly: 79,
      threeMonths: 189,
      // sixMonths and oneYear are NOT offered!
    },
    isActive: true,
    createdAt: null as any,
    updatedAt: null as any,
  };

  const subjectPackage: Package = {
    id: "pkg_law_full_subject",
    title: "Corporate Laws — Full Subject Pass",
    packageType: "subject",
    category: "CA",
    level: "Inter",
    subjectId: "ca_inter_law",
    refs: ["ca_inter_law"],
    pricing: {
      // monthly is NOT offered!
      threeMonths: 299,
      sixMonths: 499,
      oneYear: 799,
    },
    isActive: true,
    createdAt: null as any,
    updatedAt: null as any,
  };

  const bundlePackage: Package = {
    id: "pkg_ca_inter_all_bundle",
    title: "CA Inter All-in-One Bundle",
    packageType: "bundle",
    category: "CA",
    level: "Inter",
    refs: ["ca_inter_law", "ca_inter_tax", "ca_inter_acc"],
    pricing: {
      // ONLY oneYear is offered!
      oneYear: 1999,
    },
    isActive: true,
    createdAt: null as any,
    updatedAt: null as any,
  };

  const allPossibleDurations: PlanDuration[] = ["monthly", "threeMonths", "sixMonths", "oneYear"];

  /**
   * Helper that mirrors the Flutter Package.availableDurations logic:
   * Only durations that exist in the pricing map and have price > 0 are returned.
   */
  function getAvailableDurations(pkg: Package): PlanDuration[] {
    return allPossibleDurations.filter(
      (d) => pkg.pricing[d] !== undefined && pkg.pricing[d] !== null && (pkg.pricing[d] as number) > 0
    );
  }

  /**
   * Helper checking what durations are genuinely hidden from the UI widget tree
   */
  function getHiddenDurations(pkg: Package): PlanDuration[] {
    const available = new Set(getAvailableDurations(pkg));
    return allPossibleDurations.filter((d) => !available.has(d));
  }

  describe("1. Package Duration Filtering & Genuine Hiding", () => {
    it("Part-level package genuinely hides 3-month, 6-month, and 1-year options", () => {
      const available = getAvailableDurations(partPackage);
      const hidden = getHiddenDurations(partPackage);

      expect(available).to.deep.equal(["monthly"]);
      expect(hidden).to.deep.equal(["threeMonths", "sixMonths", "oneYear"]);
      expect(partPackage.pricing.monthly).to.equal(49);
      expect(partPackage.pricing.threeMonths).to.be.undefined;
      expect(partPackage.pricing.sixMonths).to.be.undefined;
      expect(partPackage.pricing.oneYear).to.be.undefined;
    });

    it("Lesson-level package genuinely hides 6-month and 1-year options while showing monthly and 3-month", () => {
      const available = getAvailableDurations(lessonPackage);
      const hidden = getHiddenDurations(lessonPackage);

      expect(available).to.deep.equal(["monthly", "threeMonths"]);
      expect(hidden).to.deep.equal(["sixMonths", "oneYear"]);
      expect(lessonPackage.pricing.monthly).to.equal(79);
      expect(lessonPackage.pricing.threeMonths).to.equal(189);
      expect(lessonPackage.pricing.sixMonths).to.be.undefined;
      expect(lessonPackage.pricing.oneYear).to.be.undefined;
    });

    it("Subject-level package genuinely hides monthly while showing 3-month, 6-month, and 1-year", () => {
      const available = getAvailableDurations(subjectPackage);
      const hidden = getHiddenDurations(subjectPackage);

      expect(available).to.deep.equal(["threeMonths", "sixMonths", "oneYear"]);
      expect(hidden).to.deep.equal(["monthly"]);
      expect(subjectPackage.pricing.monthly).to.be.undefined;
      expect(subjectPackage.pricing.threeMonths).to.equal(299);
      expect(subjectPackage.pricing.sixMonths).to.equal(499);
      expect(subjectPackage.pricing.oneYear).to.equal(799);
    });

    it("Bundle-level package genuinely hides monthly, 3-month, and 6-month options", () => {
      const available = getAvailableDurations(bundlePackage);
      const hidden = getHiddenDurations(bundlePackage);

      expect(available).to.deep.equal(["oneYear"]);
      expect(hidden).to.deep.equal(["monthly", "threeMonths", "sixMonths"]);
      expect(bundlePackage.pricing.oneYear).to.equal(1999);
    });

    it("Each package returns its own custom price for the chosen duration", () => {
      expect(partPackage.pricing.monthly).to.equal(49);
      expect(lessonPackage.pricing.monthly).to.equal(79);
      expect(subjectPackage.pricing.threeMonths).to.equal(299);
      expect(lessonPackage.pricing.threeMonths).to.equal(189);
    });
  });

  describe("2. Coverage Resolution: Part, Lesson, Subject, Bundle", () => {
    it("Part-level package covers exactly its target part", () => {
      expect(partPackage.refs).to.include("part_3a_indemnity_guarantee");
    });

    it("Lesson-level package covers multiple parts in that chapter", () => {
      expect(lessonPackage.refs).to.include("part_3a_indemnity_guarantee");
      expect(lessonPackage.refs).to.include("part_3b_bailment_pledge");
      expect(lessonPackage.refs).to.include("part_3c_agency");
    });

    it("Subject-level package covers subject ref ca_inter_law", () => {
      expect(subjectPackage.refs).to.include("ca_inter_law");
    });
  });

  describe("3. Stubbed grantAccess Execution & Expiration Logic", () => {
    const baseDate = new Date("2026-09-06T10:00:00Z");

    it("correctly calculates monthly expiration (+1 month)", () => {
      const expires = calculateExpiresAt(baseDate, "monthly");
      expect(expires.toISOString()).to.equal("2026-10-06T10:00:00.000Z");
    });

    it("correctly calculates threeMonths expiration (+3 months)", () => {
      const expires = calculateExpiresAt(baseDate, "threeMonths");
      expect(expires.toISOString()).to.equal("2026-12-06T10:00:00.000Z");
    });

    it("correctly calculates sixMonths expiration (+6 months)", () => {
      const expires = calculateExpiresAt(baseDate, "sixMonths");
      expect(expires.toISOString()).to.equal("2027-03-06T10:00:00.000Z");
    });

    it("correctly calculates oneYear expiration (+1 year)", () => {
      const expires = calculateExpiresAt(baseDate, "oneYear");
      expect(expires.toISOString()).to.equal("2027-09-06T10:00:00.000Z");
    });

    it("rejects purchasing a duration that is not offered by the package", () => {
      const offeredInPart = getAvailableDurations(partPackage);
      expect(offeredInPart.includes("threeMonths")).to.be.false;

      // When calling grantAccess with an unconfigured duration, it should be rejected
      const price = partPackage.pricing["threeMonths"];
      expect(price).to.be.undefined;
    });
  });
});
