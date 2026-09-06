import { expect } from "chai";
import { calculateExpiresAt } from "../functions/src/grantAccess";
import { PlanDuration } from "../functions/src/types";

describe("Notify - Cloud Functions Logic Unit Tests", () => {
  const baseDate = new Date("2026-09-06T10:00:00Z");

  it("calculates correct expiration for monthly plan (+1 month)", () => {
    const expires = calculateExpiresAt(baseDate, "monthly");
    expect(expires.toISOString()).to.equal("2026-10-06T10:00:00.000Z");
  });

  it("calculates correct expiration for threeMonths plan (+3 months)", () => {
    const expires = calculateExpiresAt(baseDate, "threeMonths");
    expect(expires.toISOString()).to.equal("2026-12-06T10:00:00.000Z");
  });

  it("calculates correct expiration for sixMonths plan (+6 months)", () => {
    const expires = calculateExpiresAt(baseDate, "sixMonths");
    expect(expires.toISOString()).to.equal("2027-03-06T10:00:00.000Z");
  });

  it("calculates correct expiration for oneYear plan (+1 year)", () => {
    const expires = calculateExpiresAt(baseDate, "oneYear");
    expect(expires.toISOString()).to.equal("2027-09-06T10:00:00.000Z");
  });

  it("throws error for invalid plan duration", () => {
    expect(() => calculateExpiresAt(baseDate, "invalidPlan" as PlanDuration)).to.throw(
      "Invalid plan duration"
    );
  });
});
