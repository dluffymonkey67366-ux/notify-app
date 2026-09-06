import 'dart:convert';
import 'package:flutter/material.dart';

/// Available highlight colors for in-reader note annotation
enum HighlightColor {
  amber,
  emerald,
  coral;

  String get hex {
    switch (this) {
      case HighlightColor.amber:
        return '#F59E0B';
      case HighlightColor.emerald:
        return '#10B981';
      case HighlightColor.coral:
        return '#F43F5E';
    }
  }

  String get rgba {
    switch (this) {
      case HighlightColor.amber:
        return 'rgba(245, 158, 11, 0.32)';
      case HighlightColor.emerald:
        return 'rgba(16, 185, 129, 0.32)';
      case HighlightColor.coral:
        return 'rgba(244, 63, 94, 0.32)';
    }
  }

  Color get color {
    switch (this) {
      case HighlightColor.amber:
        return const Color(0xFFF59E0B);
      case HighlightColor.emerald:
        return const Color(0xFF10B981);
      case HighlightColor.coral:
        return const Color(0xFFF43F5E);
    }
  }

  String get label {
    switch (this) {
      case HighlightColor.amber:
        return 'Amber';
      case HighlightColor.emerald:
        return 'Emerald';
      case HighlightColor.coral:
        return 'Coral';
    }
  }
}

/// A DRM-safe persistent text highlight in the HTML note reader
class ReaderHighlight {
  final String id;
  final String partId;
  final String text;
  final HighlightColor color;
  final int startOffset;
  final int endOffset;
  final String? anchorNodeId;
  final DateTime createdAt;

  ReaderHighlight({
    required this.id,
    required this.partId,
    required this.text,
    required this.color,
    this.startOffset = 0,
    this.endOffset = 0,
    this.anchorNodeId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'partId': partId,
        'text': text,
        'color': color.name,
        'startOffset': startOffset,
        'endOffset': endOffset,
        if (anchorNodeId != null) 'anchorNodeId': anchorNodeId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReaderHighlight.fromMap(Map<String, dynamic> map) => ReaderHighlight(
        id: map['id'] as String? ?? '',
        partId: map['partId'] as String? ?? '',
        text: map['text'] as String? ?? '',
        color: HighlightColor.values.firstWhere(
          (c) => c.name == map['color'],
          orElse: () => HighlightColor.amber,
        ),
        startOffset: (map['startOffset'] as num?)?.toInt() ?? 0,
        endOffset: (map['endOffset'] as num?)?.toInt() ?? 0,
        anchorNodeId: map['anchorNodeId'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());
  factory ReaderHighlight.fromJson(String jsonStr) =>
      ReaderHighlight.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

/// A reader bookmark for quick jumping to sections or positions
class ReaderBookmark {
  final String id;
  final String partId;
  final String title;
  final String sectionId;
  final int scrollOffset;
  final DateTime createdAt;

  ReaderBookmark({
    required this.id,
    required this.partId,
    required this.title,
    required this.sectionId,
    this.scrollOffset = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'partId': partId,
        'title': title,
        'sectionId': sectionId,
        'scrollOffset': scrollOffset,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReaderBookmark.fromMap(Map<String, dynamic> map) => ReaderBookmark(
        id: map['id'] as String? ?? '',
        partId: map['partId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        sectionId: map['sectionId'] as String? ?? '',
        scrollOffset: (map['scrollOffset'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());
  factory ReaderBookmark.fromJson(String jsonStr) =>
      ReaderBookmark.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

/// Encrypted container bundle holding all user annotations for a specific part
class NoteAnnotationsBundle {
  final String partId;
  final List<ReaderHighlight> highlights;
  final List<ReaderBookmark> bookmarks;

  const NoteAnnotationsBundle({
    required this.partId,
    this.highlights = const [],
    this.bookmarks = const [],
  });

  NoteAnnotationsBundle copyWith({
    List<ReaderHighlight>? highlights,
    List<ReaderBookmark>? bookmarks,
  }) {
    return NoteAnnotationsBundle(
      partId: partId,
      highlights: highlights ?? this.highlights,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }

  Map<String, dynamic> toMap() => {
        'partId': partId,
        'highlights': highlights.map((h) => h.toMap()).toList(),
        'bookmarks': bookmarks.map((b) => b.toMap()).toList(),
      };

  factory NoteAnnotationsBundle.fromMap(Map<String, dynamic> map) {
    return NoteAnnotationsBundle(
      partId: map['partId'] as String? ?? '',
      highlights: (map['highlights'] as List<dynamic>?)
              ?.map((item) => ReaderHighlight.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      bookmarks: (map['bookmarks'] as List<dynamic>?)
              ?.map((item) => ReaderBookmark.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String toJson() => jsonEncode(toMap());
  factory NoteAnnotationsBundle.fromJson(String jsonStr) =>
      NoteAnnotationsBundle.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}
