import { Timestamp } from "firebase-admin/firestore";

/**
 * Plan duration choices for Notify packages
 */
export type PlanDuration = "monthly" | "threeMonths" | "sixMonths" | "oneYear";

/**
 * Package types that can be created and purchased
 */
export type PackageType = "part" | "lesson" | "subject" | "bundle";

/**
 * Note file formats supported by Notify
 */
export type NoteFileType = "html" | "pdf";

/**
 * Subject schema: Top-level category-agnostic exam course unit
 * Firestore path: subjects/{subjectId}
 */
export interface Subject {
  id: string;
  title: string;
  category: string; // "CA", "CMA", etc.
  level: string; // "Foundation", "Inter", "Final"
  description: string;
  order: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Lesson schema: Chapter or topic grouping within a subject
 * Firestore path: subjects/{subjectId}/lessons/{lessonId}
 */
export interface Lesson {
  id: string;
  subjectId: string;
  title: string;
  order: number;
  description?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Part schema: The smallest atomic content unit (HTML or PDF)
 * Firestore path: subjects/{subjectId}/lessons/{lessonId}/parts/{partId}
 */
export interface Part {
  id: string;
  lessonId: string;
  subjectId: string;
  title: string;
  order: number;
  fileType: NoteFileType;
  previewRef: string; // e.g. "content/preview/{partId}.html" (public/trimmed)
  fullRef: string; // e.g. "content/full/{partId}.html" (protected/signed URL only)
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Pricing map for packages. Any subset of durations may be configured.
 */
export interface PackagePricing {
  monthly?: number; // Price in INR
  threeMonths?: number;
  sixMonths?: number;
  oneYear?: number;
}

/**
 * Package schema: Sellable unit (part, lesson, subject, or custom bundle)
 * Firestore path: packages/{packageId}
 */
export interface Package {
  id: string;
  title: string;
  description?: string;
  packageType: PackageType;
  category: string;
  level: string;
  subjectId?: string;
  refs: string[]; // partId(s), lessonId(s), or subjectId(s) covered
  pricing: PackagePricing;
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Purchase schema: Record of granted access with verified server-side expiry
 * Firestore path: purchases/{purchaseId} and purchases/{userId}_{partId}
 */
export interface Purchase {
  id: string;
  userId: string;
  packageId: string;
  packageType: PackageType;
  planDuration: PlanDuration;
  purchasedAt: Timestamp;
  expiresAt: Timestamp;
  status: "active" | "expired" | "revoked";
  amount?: number;
  currency?: string;
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  razorpaySignature?: string;
  coveredPartIds: string[];
  coveredLessonIds?: string[];
  coveredSubjectIds?: string[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * User Session schema: Enforces single active session per account
 * Firestore path: users/{uid}/session/current
 */
export interface UserSession {
  deviceId: string;
  loginAt: Timestamp;
  lastActiveAt?: Timestamp;
  platform?: string;
  invalidated?: boolean;
  invalidationReason?: string;
}

/**
 * User Progress schema: Tracks reading position per part
 * Firestore path: users/{uid}/progress/{partId}
 */
export interface UserProgress {
  partId: string;
  scrollY?: number; // HTML reader scroll position in px
  pageNumber?: number; // PDF reader page index (1-based)
  totalScrollY?: number;
  totalPages?: number;
  completionPercentage?: number;
  updatedAt: Timestamp;
}

/**
 * Violation schema: Capture/screenshot detection telemetry
 * Firestore path: violations/{violationId}
 */
export interface ViolationRecord {
  id: string;
  userId: string;
  partId: string;
  type: "screenshot" | "recording";
  platform: "ios" | "desktop" | "android";
  timestamp: Timestamp;
}

/**
 * Admin Alert schema: Real-time security alert for creator dashboard
 * Firestore path: admin_alerts/{alertId}
 */
export interface AdminAlert {
  id: string;
  userId: string;
  partId: string;
  type: string;
  platform: string;
  sessionViolationCount: number;
  lifetimeViolationCount: number;
  timestamp: Timestamp;
  forceLoggedOut: boolean;
}
