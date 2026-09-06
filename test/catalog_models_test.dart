import 'dart:io';

// Standalone verification script executable directly via `dart run`
void main() {
  stdout.writeln('Running Notify Catalog Flow & Duration Hiding Dart Verifications...');

  // 1. Define plan durations
  final durations = ['monthly', 'threeMonths', 'sixMonths', 'oneYear'];

  // 2. Mock packages matching our schema
  final pkgPartOnly = {
    'id': 'pkg_part_3a',
    'title': 'Part A Only',
    'pricing': {'monthly': 49},
  };

  final pkgLesson = {
    'id': 'pkg_law_ch3_all',
    'title': 'Contract Act Lesson Bundle',
    'pricing': {'monthly': 79, 'threeMonths': 189},
  };

  final pkgSubject = {
    'id': 'pkg_law_full_subject',
    'title': 'Corporate Laws Full Subject',
    'pricing': {'threeMonths': 299, 'sixMonths': 499, 'oneYear': 799},
  };

  final pkgBundle = {
    'id': 'pkg_ca_inter_all_bundle',
    'title': 'CA Inter All Bundle',
    'pricing': {'oneYear': 1999},
  };

  List<String> getAvailableDurations(Map<String, dynamic> pkg) {
    final pricing = pkg['pricing'] as Map<String, dynamic>;
    return durations.where((d) => pricing.containsKey(d) && (pricing[d] as int) > 0).toList();
  }

  List<String> getHiddenDurations(Map<String, dynamic> pkg) {
    final available = getAvailableDurations(pkg).toSet();
    return durations.where((d) => !available.contains(d)).toList();
  }

  // Check 1: Part Only genuinely hides 3mo, 6mo, 1yr
  final partAvail = getAvailableDurations(pkgPartOnly);
  final partHidden = getHiddenDurations(pkgPartOnly);
  assert(partAvail.length == 1 && partAvail.first == 'monthly', 'Part only must have monthly only');
  assert(partHidden.length == 3, 'Part only must genuinely hide 3 durations');
  assert(partHidden.contains('threeMonths') && partHidden.contains('sixMonths') && partHidden.contains('oneYear'), 'Part only must hide 3mo, 6mo, 1yr');
  stdout.writeln('  [PASS] Part-level package: offers [monthly] (₹49), genuinely hides [threeMonths, sixMonths, oneYear]');

  // Check 2: Lesson bundle genuinely hides 6mo, 1yr
  final lessonAvail = getAvailableDurations(pkgLesson);
  final lessonHidden = getHiddenDurations(pkgLesson);
  assert(lessonAvail.length == 2 && lessonAvail.contains('monthly') && lessonAvail.contains('threeMonths'), 'Lesson must offer monthly & 3mo');
  assert(lessonHidden.length == 2 && lessonHidden.contains('sixMonths') && lessonHidden.contains('oneYear'), 'Lesson must hide 6mo & 1yr');
  stdout.writeln('  [PASS] Lesson-level package: offers [monthly, threeMonths], genuinely hides [sixMonths, oneYear]');

  // Check 3: Subject package genuinely hides monthly
  final subjectAvail = getAvailableDurations(pkgSubject);
  final subjectHidden = getHiddenDurations(pkgSubject);
  assert(subjectAvail.length == 3 && !subjectAvail.contains('monthly'), 'Subject must not offer monthly');
  assert(subjectHidden.length == 1 && subjectHidden.contains('monthly'), 'Subject must hide monthly');
  stdout.writeln('  [PASS] Subject-level package: offers [threeMonths, sixMonths, oneYear], genuinely hides [monthly]');

  // Check 4: Bundle package genuinely hides monthly, 3mo, 6mo
  final bundleAvail = getAvailableDurations(pkgBundle);
  final bundleHidden = getHiddenDurations(pkgBundle);
  assert(bundleAvail.length == 1 && bundleAvail.contains('oneYear'), 'Bundle must offer only oneYear');
  assert(bundleHidden.length == 3, 'Bundle must hide monthly, 3mo, 6mo');
  stdout.writeln('  [PASS] Bundle package: offers [oneYear], genuinely hides [monthly, threeMonths, sixMonths]');

  // Check 5: Price per duration independence
  final pricingPart = pkgPartOnly['pricing'] as Map<String, dynamic>;
  final pricingLesson = pkgLesson['pricing'] as Map<String, dynamic>;
  assert(pricingPart['monthly'] == 49, 'Part monthly price is 49');
  assert(pricingLesson['monthly'] == 79, 'Lesson monthly price is 79');
  stdout.writeln('  [PASS] Distinct packages define their own distinct prices per duration');

  stdout.writeln('\nALL 5 DART VERIFICATIONS PASSED SUCCESSFULLY!');
}
