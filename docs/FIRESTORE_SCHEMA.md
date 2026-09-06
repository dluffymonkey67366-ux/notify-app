# Notify — Complete Firestore Schema Specification

This document details the complete Firestore schema, collection hierarchies, document structures, and indexing rules for **Notify**, a secure, view-only digital notes platform for CA/CMA students.

---

## 1. Hierarchy Overview

```
subjects/{subjectId}
  └── lessons/{lessonId}
        └── parts/{partId}
              └── protected/content

packages/{packageId}
purchases/{purchaseId}

users/{uid}
  ├── session/current
  └── progress/{partId}

violations/{violationId}
admin_alerts/{alertId}
```

---

## 2. Document Schemas

### `subjects/{subjectId}`
Represents a course or subject (e.g. CA Inter — Corporate and Other Laws). Category-agnostic (designed for CA, CMA, CS).

```json
{
  "id": "ca_inter_law",
  "title": "Corporate and Other Laws",
  "category": "CA",
  "level": "Inter",
  "description": "Comprehensive notes covering Companies Act, 2013 and Other Laws for CA Intermediate.",
  "order": 1,
  "createdAt": "2026-09-06T00:00:00Z",
  "updatedAt": "2026-09-06T00:00:00Z"
}
```

### `subjects/{subjectId}/lessons/{lessonId}`
Groups related parts into a chapter or module.

```json
{
  "id": "chapter_3_contract_act",
  "subjectId": "ca_inter_law",
  "title": "Chapter 3 - The Indian Contract Act, 1872",
  "order": 3,
  "description": "Special contracts: Indemnity, Guarantee, Bailment, Pledge, and Agency.",
  "createdAt": "2026-09-06T00:00:00Z",
  "updatedAt": "2026-09-06T00:00:00Z"
}
```

### `subjects/{subjectId}/lessons/{lessonId}/parts/{partId}`
Smallest catalog content metadata unit (HTML or PDF). Publicly readable by anyone for catalog browsing, titles, order, and free trimmed previews. Does NOT expose `fullRef`.

```json
{
  "id": "part_3a_indemnity_guarantee",
  "lessonId": "chapter_3_contract_act",
  "subjectId": "ca_inter_law",
  "title": "Part A: Contract of Indemnity and Guarantee",
  "order": 1,
  "fileType": "html",
  "previewRef": "content/preview/part_3a_indemnity_guarantee.html",
  "createdAt": "2026-09-06T00:00:00Z",
  "updatedAt": "2026-09-06T00:00:00Z"
}
```

### `subjects/{subjectId}/lessons/{lessonId}/parts/{partId}/protected/content`
Protected content subdocument containing `fullRef` and protected asset paths.
NON-NEGOTIABLE: Protected by security rules; requires a valid non-expired purchase covering the part, lesson, or subject.

```json
{
  "fullRef": "content/full/part_3a_indemnity_guarantee.html",
  "updatedAt": "2026-09-06T00:00:00Z"
}
```

### `packages/{packageId}`
Sellable units at any level (Part, Lesson, Subject, or custom bundle). Pricing is flexible per package and per duration.

```json
{
  "id": "pkg_law_ch3_all",
  "title": "Contract Act - Complete Chapter 3 Bundle",
  "description": "Unlocks all parts of Chapter 3 (Contract Act)",
  "packageType": "lesson",
  "category": "CA",
  "level": "Inter",
  "subjectId": "ca_inter_law",
  "refs": [
    "part_3a_indemnity_guarantee",
    "part_3b_bailment_pledge",
    "part_3c_agency"
  ],
  "pricing": {
    "monthly": 49,
    "threeMonths": 129,
    "sixMonths": 229,
    "oneYear": 399
  },
  "isActive": true,
  "createdAt": "2026-09-06T00:00:00Z",
  "updatedAt": "2026-09-06T00:00:00Z"
}
```

### `purchases/{purchaseId}`
Server-verified record of granted access with non-forgeable `expiresAt`. Written strictly by Cloud Functions.
Also materialized as `purchases/{userId}_{partId}` for O(1) security rule evaluation.

```json
{
  "id": "purch_usr123_pkg_law_ch3",
  "userId": "user_firebase_uid_123",
  "packageId": "pkg_law_ch3_all",
  "packageType": "lesson",
  "planDuration": "threeMonths",
  "purchasedAt": "2026-09-06T10:00:00Z",
  "expiresAt": "2026-12-06T10:00:00Z",
  "status": "active",
  "amount": 129,
  "currency": "INR",
  "razorpayOrderId": "order_Hk8192sKx",
  "razorpayPaymentId": "pay_9821kKdOas",
  "coveredPartIds": [
    "part_3a_indemnity_guarantee",
    "part_3b_bailment_pledge",
    "part_3c_agency"
  ],
  "coveredLessonIds": ["chapter_3_contract_act"],
  "coveredSubjectIds": ["ca_inter_law"],
  "createdAt": "2026-09-06T10:00:00Z",
  "updatedAt": "2026-09-06T10:00:00Z"
}
```

### `users/{uid}/session/current`
Single active session enforcement. New login updates `deviceId` and `loginAt`. Any mismatch forces sign-out.

```json
{
  "deviceId": "device_uuid_android_abc123",
  "loginAt": "2026-09-06T10:00:00Z",
  "lastActiveAt": "2026-09-06T10:15:00Z",
  "platform": "android",
  "invalidated": false
}
```

### `users/{uid}/progress/{partId}`
Restores exact read position (scrollY for HTML or pageNumber for PDF). Auto-synced periodically.

```json
{
  "partId": "part_3a_indemnity_guarantee",
  "scrollY": 1420.5,
  "pageNumber": 14,
  "completionPercentage": 65,
  "updatedAt": "2026-09-06T10:20:00Z"
}
```

### `violations/{violationId}`
Client-reported screenshot or screen-recording detection event.

```json
{
  "id": "viol_99182312",
  "userId": "user_firebase_uid_123",
  "partId": "part_3a_indemnity_guarantee",
  "type": "screenshot",
  "platform": "ios",
  "timestamp": "2026-09-06T10:21:00Z"
}
```

### `admin_alerts/{alertId}`
Internal security notification generated by Cloud Function on each violation event.

```json
{
  "id": "alert_99182312",
  "userId": "user_firebase_uid_123",
  "partId": "part_3a_indemnity_guarantee",
  "type": "screenshot",
  "platform": "ios",
  "sessionViolationCount": 1,
  "lifetimeViolationCount": 4,
  "timestamp": "2026-09-06T10:21:01Z",
  "forceLoggedOut": true
}
```
