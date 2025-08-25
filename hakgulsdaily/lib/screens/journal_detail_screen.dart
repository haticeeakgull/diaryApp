import 'package:flutter/material.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hakgulsdaily/main.dart';
import 'package:hakgulsdaily/screens/ai_feedback_screen.dart';
import 'package:hakgulsdaily/services/ai_analysis_service.dart';
import 'package:flutter/foundation.dart'; // Bu satır eklendi

/// Helper function to process the image file in a separate isolate.
/// This prevents the UI from freezing while reading a large file.
/// We are reading the file as bytes, which is more efficient for uploading
/// than passing the whole File object.
Future<Uint8List?> _processImageInIsolate(String? path) async {
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return await file.readAsBytes();
}

class JournalDetailScreen extends StatefulWidget {
  final JournalEntry entry;
  final String collectionPath;
  final bool isEditable;

  const JournalDetailScreen({
    super.key,
    required this.entry,
    required this.collectionPath,
    this.isEditable = true,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  // Kullanıcı arayüzü için TextEditingController'lar ve state değişkenleri
  late TextEditingController _textController;
  late TextEditingController _artisticController;
  late TextEditingController _sportiveController;
  late TextEditingController _academicController;
  late TextEditingController _socialController;
  int? _selectedScore;

  // Yükleme için File nesnesi veya UI'da göstermek için byte verisi
  File? _selectedImageFile; 
  Uint8List? _selectedImageBytes;

  // Yetkilendirme ve düzenleme durumu için değişkenler
  late final bool _isAuthor;
  late bool _isEditing;

  // İşlem durumu için değişken
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    // Kullanıcının yazar olup olmadığını kontrol et
    _isAuthor = (currentUser?.uid == widget.entry.authorId);
    // Başlangıçta düzenleme modunu belirle
    _isEditing = _isAuthor && widget.isEditable;
    
    // Mevcut günlük verileriyle controller'ları başlat
    _textController = TextEditingController(text: widget.entry.text);
    _artisticController = TextEditingController(text: widget.entry.artisticActivity);
    _sportiveController = TextEditingController(text: widget.entry.sportiveActivity);
    _academicController = TextEditingController(text: widget.entry.academicActivity);
    _socialController = TextEditingController(text: widget.entry.socialActivity);
    _selectedScore = widget.entry.score;
  }

  @override
  void dispose() {
    // Widget atıldığında controller'ları temizle
    _textController.dispose();
    _artisticController.dispose();
    _sportiveController.dispose();
    _academicController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  // Galeriden fotoğraf seçme işlevi
  Future<void> _pickImage() async {
    if (_isSaving) {
      _showSnackBar('Kayıt işlemi devam ederken fotoğraf seçilemez.');
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // compute kullanarak dosya okuma işlemini izolata taşı
        final bytes = await compute(_processImageInIsolate, pickedFile.path);

        if (bytes != null) {
          setState(() {
            _selectedImageFile = File(pickedFile.path);
            _selectedImageBytes = bytes;
          });
          _showSnackBar('Yeni fotoğraf başarıyla seçildi.');
        } else {
          _showSnackBar('Fotoğraf işlenirken bir hata oluştu.', isError: true);
        }
      } else {
        _showSnackBar('Fotoğraf seçimi iptal edildi.');
      }
    } catch (e) {
      debugPrint('Fotoğraf işleme hatası: $e');
      _showSnackBar('Fotoğraf işlenirken bir hata oluştu: $e', isError: true);
    } finally {
      setState(() {
        _isPickingImage = false;
      });
    }
  }

  // Mevcut fotoğrafı kaldırma işlevi
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
    });
    _showSnackBar('Fotoğraf kaldırıldı.');
  }

  // SnackBar göstermek için yardımcı fonksiyon
  void _showSnackBar(String message, {bool isError = false}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Eski fotoğrafı Firebase Storage'dan silme işlevi
  Future<void> _deleteOldImageFromStorage(String imageUrl) async {
    try {
      final oldImageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await oldImageRef.delete();
      debugPrint('Eski fotoğraf Firebase Storage\'dan başarıyla silindi.');
    } on FirebaseException catch (e) {
      // Dosya zaten yoksa hata vermemeli. Sadece logla.
      if (e.code != 'object-not-found') {
        debugPrint('Eski fotoğrafı silme hatası: ${e.code} - ${e.message}');
      }
    }
  }

  // Günlüğü güncelleme işlevi
  Future<void> _updateJournalEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.entry.docId == null) {
      _showSnackBar('Günlüğü güncellemek için giriş yapmalısınız veya belge kimliği eksik.', isError: true);
      return;
    }

    setState(() { _isSaving = true; });

    try {
      String? newImageUrl;
      List<String> oldImageUrls = widget.entry.imageUrls;

      // Yeni bir fotoğraf seçildiyse, Firebase Storage'a yükle ve eskisini sil
      if (_selectedImageBytes != null) { // Değişiklik: _selectedImageFile yerine _selectedImageBytes kullanıldı
        if (oldImageUrls.isNotEmpty) {
          await _deleteOldImageFromStorage(oldImageUrls.first); // Eski fotoğrafı sil
        }
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('journal_images')
            .child(user.uid)
            .child('${DateTime.now().toIso8601String()}.jpg');
        await storageRef.putData(_selectedImageBytes!); // Değişiklik: putFile yerine putData kullanıldı
        newImageUrl = await storageRef.getDownloadURL();
        debugPrint('Yeni fotoğraf Firebase Storage\'a başarıyla yüklendi.');
      } else if (_selectedImageBytes == null && oldImageUrls.isNotEmpty) {
        // Kullanıcı fotoğrafı kaldırdıysa, Storage'daki dosyasını sil
        await _deleteOldImageFromStorage(oldImageUrls.first);
      } else if (oldImageUrls.isNotEmpty) {
        // Fotoğraf değiştirilmediyse mevcut URL'yi kullan
        newImageUrl = oldImageUrls.first;
      }

      // Final JournalEntry nesnesini oluştur
      final updatedEntry = JournalEntry(
        text: _textController.text,
        score: _selectedScore,
        date: widget.entry.date,
        imageUrls: newImageUrl != null ? [newImageUrl] : [],
        artisticActivity: _artisticController.text.isNotEmpty ? _artisticController.text : null,
        sportiveActivity: _sportiveController.text.isNotEmpty ? _sportiveController.text : null,
        academicActivity: _academicController.text.isNotEmpty ? _academicController.text : null,
        socialActivity: _socialController.text.isNotEmpty ? _socialController.text : null,
        authorId: widget.entry.authorId,
        originalDocPath: widget.entry.originalDocPath,
      );

      // Firestore belgesini güncelle
      final docRef = widget.entry.originalDocPath != null
          ? FirebaseFirestore.instance.doc(widget.entry.originalDocPath!)
          : FirebaseFirestore.instance.collection(widget.collectionPath).doc(widget.entry.docId);

      await docRef.update(updatedEntry.toJson());
      debugPrint('Firestore belgesi başarıyla güncellendi.');

      // Yapay zeka analizi ve yönlendirme
      final aiFeedback = await getAiFeedback(updatedEntry.text);
      debugPrint("AI Geri Bildirimi: $aiFeedback");

      // Kaydetme işleminden sonra ekranı kapatıp ana ekrana dönmek yerine, AI geri bildirim ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => AiFeedbackScreen(
              feedback: aiFeedback,
            ),
          ),
        );
      }
      _showSnackBar('Günlük başarıyla güncellendi!');
      
    } on FirebaseException catch (e) {
      debugPrint('Firebase Hatası: ${e.code} - ${e.message}');
      _showSnackBar('Günlük güncellenirken Firebase hatası oluştu: ${e.message}', isError: true);
    } catch (e) {
      debugPrint('Genel Hata: $e');
      _showSnackBar('Günlük güncellenirken beklenmedik bir hata oluştu: $e', isError: true);
    } finally {
      // İşlem başarısız olsa bile, UI durumunu sıfırla
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _selectedImageFile = null;
          _selectedImageBytes = null;
        });
      }
    }
  }

  // Günlük paylaşma işlevi
  void _shareJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Paylaşım yapmak için giriş yapmalısınız.', isError: true);
      return;
    }

    final TextEditingController recipientEmailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Günlüğü Paylaş'),
          content: TextField(
            controller: recipientEmailController,
            decoration: const InputDecoration(hintText: "Alıcının e-posta adresi"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Paylaş'),
              onPressed: () async {
                final recipientEmail = recipientEmailController.text.trim();
                if (recipientEmail.isEmpty) {
                  _showSnackBar('Lütfen bir e-posta adresi girin.', isError: true);
                  return;
                }
                Navigator.of(context).pop();
                await _performSharing(user.uid, recipientEmail);
              },
            ),
          ],
        );
      },
    );
  }

  // Paylaşım işlemini gerçekleştiren yardımcı fonksiyon
  Future<void> _performSharing(String authorId, String recipientEmail) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showSnackBar('Kullanıcı bulunamadı.', isError: true);
        return;
      }

      final recipientUid = querySnapshot.docs.first.id;
      final sharedEntryData = widget.entry.toJson();
      sharedEntryData['authorId'] = authorId;
      sharedEntryData['recipientId'] = recipientUid;
      if (widget.entry.docId != null && widget.collectionPath.isNotEmpty) {
        sharedEntryData['originalDocPath'] = FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.entry.docId)
            .path;
      }

      await FirebaseFirestore.instance
          .collection('shared_journals')
          .add(sharedEntryData);

      _showSnackBar('$recipientEmail ile başarıyla paylaşıldı!');
    } on FirebaseException catch (e) {
      _showSnackBar('Paylaşım sırasında bir hata oluştu: ${e.message}', isError: true);
    }
  }

  // Kategori metin alanlarını oluşturan yardımcı fonksiyon
  Widget _buildCategoryTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: enabled ? Colors.grey[200] : Colors.grey[100],
        ),
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Günlüğü Düzenle' : 'Günlük Detayı'),
        centerTitle: true,
        actions: [
          // Yazar ve düzenleme modunda değilse Edit ve Share butonlarını göster
          if (_isAuthor && !_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareJournal,
            ),
          ],
          // Yazar ve düzenleme modundaysa Save ve Cancel butonlarını göster
          if (_isAuthor && _isEditing) ...[
            IconButton(
              icon: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _updateJournalEntry,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Değişiklikleri iptal etmek için verileri ilk haline getir
                  _textController.text = widget.entry.text;
                  _artisticController.text = widget.entry.artisticActivity ?? '';
                  _sportiveController.text = widget.entry.sportiveActivity ?? '';
                  _academicController.text = widget.entry.academicActivity ?? '';
                  _socialController.text = widget.entry.socialActivity ?? '';
                  _selectedScore = widget.entry.score;
                  _selectedImageFile = null;
                  _selectedImageBytes = null;
                });
              },
            ),
          ],
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarih bilgisi
                    Text(
                      DateFormat('dd MMMM yyyy, EEEE HH:mm').format(widget.entry.date),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Günlük metni
                    TextField(
                      controller: _textController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        labelText: 'Günlük Metni',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: _isEditing ? Colors.grey[200] : Colors.grey[100],
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 20),
                    // Fotoğraf gösterim alanı
                    if (_selectedImageBytes != null || widget.entry.imageUrls.isNotEmpty)
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _selectedImageBytes != null
                                  ? Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      widget.entry.imageUrls.first,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(Icons.error, color: Colors.red),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          if (_isEditing && _isAuthor)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 30),
                                onPressed: _removeImage,
                              ),
                            ),
                        ],
                      ),
                    
                    if (_isEditing && _isAuthor)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: ElevatedButton.icon(
                          onPressed: _isPickingImage || _isSaving ? null : _pickImage,
                          icon: _isPickingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate),
                          label: _isPickingImage
                              ? const Text('Fotoğraf Seçiliyor...')
                              : Text(
                                  _selectedImageBytes != null || widget.entry.imageUrls.isNotEmpty
                                      ? 'Fotoğrafı Değiştir'
                                      : 'Fotoğraf Ekle',
                                ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                    const Text(
                      'Günün Puanı:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 1; i <= 4; i++)
                          GestureDetector(
                            onTap: _isEditing
                                ? () {
                                      setState(() {
                                        _selectedScore = i;
                                      });
                                    }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectedScore == i ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                i == 1
                                    ? '😊'
                                    : i == 2
                                        ? '😐'
                                        : i == 3
                                            ? '😔'
                                            : '😡',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: _selectedScore == i ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Etkinlik Detayları:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    // Kategori metin alanları
                    _buildCategoryTextField(
                      controller: _artisticController,
                      labelText: 'Sanatsal Etkinlik',
                      icon: Icons.palette,
                      enabled: _isEditing,
                    ),
                    _buildCategoryTextField(
                      controller: _sportiveController,
                      labelText: 'Sportif Etkinlik',
                      icon: Icons.sports_soccer,
                      enabled: _isEditing,
                    ),
                    _buildCategoryTextField(
                      controller: _academicController,
                      labelText: 'Akademik Etkinlik',
                      icon: Icons.school,
                      enabled: _isEditing,
                    ),
                    _buildCategoryTextField(
                      controller: _socialController,
                      labelText: 'Sosyal Etkinlik',
                      icon: Icons.people,
                      enabled: _isEditing,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}