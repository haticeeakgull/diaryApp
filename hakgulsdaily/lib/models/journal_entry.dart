import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  // Firestore belge kimliği. final olduğu için sadece oluşturulurken atanabilir.
  final String? docId;
  final String text;
  final int? score;
  final DateTime date;
  final List<String> imageUrls;
  final String? artisticActivity;
  final String? sportiveActivity;
  final String? academicActivity;
  final String? socialActivity;
  final String? authorId;
  final String? originalDocPath;
  final String? aiFeedback;

  JournalEntry({
    this.docId,
    required this.text,
    this.score,
    required this.date,
    this.imageUrls = const [],
    this.artisticActivity,
    this.sportiveActivity,
    this.academicActivity,
    this.socialActivity,
    this.authorId,
    this.originalDocPath,
    this.aiFeedback,
  });

  // Firestore'dan veri okumak için bir fabrika kurucusu.
  factory JournalEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    // Tarih tipini kontrol etme ve dönüştürme
    DateTime entryDate;
    if (data['date'] is Timestamp) {
      entryDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      entryDate = DateTime.parse(data['date'] as String);
    } else {
      // Bilinmeyen bir tip gelirse varsayılan bir değer atayabilir veya hata fırlatabilirsiniz.
      entryDate = DateTime.now(); 
    }

    return JournalEntry(
      // Firestore belgesinin kimliğini atıyoruz.
      docId: doc.id,
      text: data['text'] as String,
      score: data['score'] as int?,
      date: entryDate, // Güncellenen tarih değerini kullan
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      artisticActivity: data['artisticActivity'] as String?,
      sportiveActivity: data['sportiveActivity'] as String?,
      academicActivity: data['academicActivity'] as String?,
      socialActivity: data['socialActivity'] as String?,
      authorId: data['authorId'] as String?,
      originalDocPath: data['originalDocPath'] as String?,
      aiFeedback: data['aiFeedback'] as String?, // AI geri bildirimi alanı eklendi
    );
  }
  
  // Herhangi bir Map<String, dynamic> nesnesinden JournalEntry oluşturmak için
  // yeni eklediğimiz fabrika kurucusu.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      docId: json['docId'] as String?, // Eğer Map içinde docId varsa al
      text: json['text'] as String,
      score: json['score'] as int?,
      date: (json['date'] is Timestamp) ? (json['date'] as Timestamp).toDate() : DateTime.parse(json['date'] as String),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      artisticActivity: json['artisticActivity'] as String?,
      sportiveActivity: json['sportiveActivity'] as String?,
      academicActivity: json['academicActivity'] as String?,
      socialActivity: json['socialActivity'] as String?,
      authorId: json['authorId'] as String?,
      originalDocPath: json['originalDocPath'] as String?,
      aiFeedback: json['aiFeedback'] as String?, // AI geri bildirimi alanı eklendi
    );
  }

  // Veriyi Firestore'a kaydetmek için bir harita oluşturur.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'score': score,
      'date': Timestamp.fromDate(date),
      'imageUrls': imageUrls,
      'artisticActivity': artisticActivity,
      'sportiveActivity': sportiveActivity,
      'academicActivity': academicActivity,
      'socialActivity': socialActivity,
      'authorId': authorId,
      'originalDocPath': originalDocPath,
      'aiFeedback': aiFeedback, // AI geri bildirimi alanı eklendi
    };
  }
}
