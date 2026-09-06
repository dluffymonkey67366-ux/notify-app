/// Data model representing a DRM-protected video-frame stream for a PDF note
class DrmPdfManifest {
  final String partId;
  final int totalPages;
  final double pageDurationSeconds;
  final List<double> pageTimestamps;
  final String dashStreamUrl;
  final String hlsStreamUrl;
  final String licenseServerUrl;
  final String drmKeyId;
  final String protectionType;

  const DrmPdfManifest({
    required this.partId,
    required this.totalPages,
    required this.pageDurationSeconds,
    required this.pageTimestamps,
    required this.dashStreamUrl,
    required this.hlsStreamUrl,
    required this.licenseServerUrl,
    required this.drmKeyId,
    required this.protectionType,
  });

  factory DrmPdfManifest.fromMap(Map<String, dynamic> map) {
    return DrmPdfManifest(
      partId: map['partId'] as String? ?? '',
      totalPages: map['totalPages'] as int? ?? 1,
      pageDurationSeconds: (map['pageDurationSeconds'] as num?)?.toDouble() ?? 2.0,
      pageTimestamps: (map['pageTimestamps'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      dashStreamUrl: map['dashStreamUrl'] as String? ?? '',
      hlsStreamUrl: map['hlsStreamUrl'] as String? ?? '',
      licenseServerUrl: map['licenseServerUrl'] as String? ?? '',
      drmKeyId: map['drmKeyId'] as String? ?? '',
      protectionType: map['protectionType'] as String? ?? 'widevine',
    );
  }

  /// Calculates video timestamp in seconds for a given 1-based page index
  double getTimestampForPage(int pageNumber) {
    if (pageNumber <= 1) return 0.0;
    if (pageNumber > totalPages) return (totalPages - 1) * pageDurationSeconds;
    return (pageNumber - 1) * pageDurationSeconds;
  }

  /// Maps a video playback position in seconds to a 1-based page number
  int getPageForTimestamp(double seconds) {
    final page = (seconds / pageDurationSeconds).floor() + 1;
    if (page < 1) return 1;
    if (page > totalPages) return totalPages;
    return page;
  }
}
