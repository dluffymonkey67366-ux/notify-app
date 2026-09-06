import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notify Catalog Flow & Duration Hiding Tests', () {
    final durations = ['monthly', 'threeMonths', 'sixMonths', 'oneYear'];

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

    test('Part-level package offers monthly and hides other durations', () {
      final partAvail = getAvailableDurations(pkgPartOnly);
      final partHidden = getHiddenDurations(pkgPartOnly);
      expect(partAvail, equals(['monthly']));
      expect(partHidden, containsAll(['threeMonths', 'sixMonths', 'oneYear']));
    });

    test('Lesson-level package offers monthly & 3mo and hides 6mo & 1yr', () {
      final lessonAvail = getAvailableDurations(pkgLesson);
      final lessonHidden = getHiddenDurations(pkgLesson);
      expect(lessonAvail, equals(['monthly', 'threeMonths']));
      expect(lessonHidden, containsAll(['sixMonths', 'oneYear']));
    });

    test('Subject-level package offers 3mo, 6mo, 1yr and hides monthly', () {
      final subjectAvail = getAvailableDurations(pkgSubject);
      final subjectHidden = getHiddenDurations(pkgSubject);
      expect(subjectAvail, equals(['threeMonths', 'sixMonths', 'oneYear']));
      expect(subjectHidden, contains('monthly'));
    });

    test('Bundle package offers only oneYear and hides other durations', () {
      final bundleAvail = getAvailableDurations(pkgBundle);
      final bundleHidden = getHiddenDurations(pkgBundle);
      expect(bundleAvail, equals(['oneYear']));
      expect(bundleHidden, containsAll(['monthly', 'threeMonths', 'sixMonths']));
    });

    test('Distinct packages define their own distinct prices per duration', () {
      final pricingPart = pkgPartOnly['pricing'] as Map<String, dynamic>;
      final pricingLesson = pkgLesson['pricing'] as Map<String, dynamic>;
      expect(pricingPart['monthly'], equals(49));
      expect(pricingLesson['monthly'], equals(79));
    });
  });
}
