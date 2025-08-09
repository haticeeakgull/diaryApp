import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String text;
  final int? score;
  final DateTime date;
  final List<String> imageUrls;
  final String? artisticActivity;
  final String? sportiveActivity;
  final String? academicActivity;
  final String? socialActivity;
  final String? authorId;
  final String? originalDocPath;  // Yeni alan
  String? docId;

  JournalEntry({
    required this.text,
    this.score,
    required this.date,
    required this.imageUrls,
    this.artisticActivity,
    this.sportiveActivity,
    this.academicActivity,
    this.socialActivity,
    this.authorId,
    this.originalDocPath,  // Yapıcıda eklendi
    this.docId,
  });

  Map<String, dynamic> toJson() {
    final data = {
      'text': text,
      'score': score,
      'date': date,
      'imageUrls': imageUrls,
      'artisticActivity': artisticActivity,
      'sportiveActivity': sportiveActivity,
      'academicActivity': academicActivity,
      'socialActivity': socialActivity,
      'authorId': authorId,
    };

    if (originalDocPath != null) {
      data['originalDocPath'] = originalDocPath;
    }

    return data;
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      text: json['text'] as String,
      score: json['score'] as int?,
      date: (json['date'] as Timestamp).toDate(),
      imageUrls: List<String>.from(json['imageUrls'] as List),
      artisticActivity: json['artisticActivity'] as String?,
      sportiveActivity: json['sportiveActivity'] as String?,
      academicActivity: json['academicActivity'] as String?,
      socialActivity: json['socialActivity'] as String?,
      authorId: json['authorId'] as String?,
      originalDocPath: json['originalDocPath'] as String?,  // JSON'dan okunuyor
    );
  }
}
