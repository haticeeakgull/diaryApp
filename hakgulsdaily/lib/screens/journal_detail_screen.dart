import 'package:flutter/material.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hakgulsdaily/main.dart'; // Global key için import

class JournalDetailScreen extends StatefulWidget {
  final JournalEntry entry;
  final String collectionPath; // Günlüğün hangi koleksiyonda olduğunu belirten parametre

  const JournalDetailScreen({
    super.key,
    required this.entry,
    required this.collectionPath,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late TextEditingController _textController;
  late TextEditingController _artisticController;
  late TextEditingController _sportiveController;
  late TextEditingController _academicController;
  late TextEditingController _socialController;
  int? _selectedScore;
  File? _selectedImage;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
    _artisticController = TextEditingController(text: widget.entry.artisticActivity);
    _sportiveController = TextEditingController(text: widget.entry.sportiveActivity);
    _academicController = TextEditingController(text: widget.entry.academicActivity);
    _socialController = TextEditingController(text: widget.entry.socialActivity);
    _selectedScore = widget.entry.score;
  }

  @override
  void dispose() {
    _textController.dispose();
    _artisticController.dispose();
    _sportiveController.dispose();
    _academicController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Yeni fotoğraf seçildi.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçimi iptal edildi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _updateJournalEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.entry.docId == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Günlüğü güncellemek için giriş yapmalısınız veya belge kimliği eksik.')),
      );
      return;
    }

    setState(() { _isSaving = true; });

    String? newImageUrl = widget.entry.imageUrls.isNotEmpty ? widget.entry.imageUrls.first : null;
    if (_selectedImage != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('journal_images')
            .child(user.uid)
            .child('${DateTime.now().toIso8601String()}.jpg');
        await storageRef.putFile(_selectedImage!);
        newImageUrl = await storageRef.getDownloadURL();
      } on FirebaseException catch (e) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenirken hata oluştu: ${e.message}')),
        );
        setState(() { _isSaving = false; });
        return;
      }
    }

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

    try {
      // Eğer originalDocPath varsa, orijinal koleksiyonundaki belgeyi güncelle
      if (widget.entry.originalDocPath != null) {
        await FirebaseFirestore.instance
            .doc(widget.entry.originalDocPath!)
            .update(updatedEntry.toJson());
      } else {
        // Eğer yoksa, mevcut koleksiyondaki belgeyi güncelle
        await FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.entry.docId)
            .update(updatedEntry.toJson());
      }

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Günlük başarıyla güncellendi!')),
      );
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _selectedImage = null;
      });
    } on FirebaseException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Günlük güncellenirken hata oluştu: ${e.message}')),
      );
      setState(() { _isSaving = false; });
    }
  }

  void _shareJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Paylaşım yapmak için giriş yapmalısınız.')),
      );
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
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Lütfen bir e-posta adresi girin.')),
                  );
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

  Future<void> _performSharing(String authorId, String recipientEmail) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .get();

      if (querySnapshot.docs.isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Kullanıcı bulunamadı.')),
        );
        return;
      }

      final recipientUid = querySnapshot.docs.first.id;
      final sharedEntryData = widget.entry.toJson();
      sharedEntryData['authorId'] = authorId;
      sharedEntryData['recipientId'] = recipientUid;
      // Orijinal belge yolu da kaydediliyor
      if (widget.entry.docId != null && widget.collectionPath.isNotEmpty) {
        sharedEntryData['originalDocPath'] = FirebaseFirestore.instance
            .collection(widget.collectionPath)
            .doc(widget.entry.docId)
            .path;
      }

      await FirebaseFirestore.instance
          .collection('shared_journals')
          .add(sharedEntryData);

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$recipientEmail ile başarıyla paylaşıldı!')),
      );
    } on FirebaseException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Paylaşım sırasında bir hata oluştu: ${e.message}')),
      );
    }
  }

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
          fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
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
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareJournal,
            ),
          if (_isEditing)
            IconButton(
              icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
              onPressed: _isSaving ? null : _updateJournalEntry,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _textController.text = widget.entry.text;
                  _artisticController.text = widget.entry.artisticActivity ?? '';
                  _sportiveController.text = widget.entry.sportiveActivity ?? '';
                  _academicController.text = widget.entry.academicActivity ?? '';
                  _socialController.text = widget.entry.socialActivity ?? '';
                  _selectedScore = widget.entry.score;
                  _selectedImage = null;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('dd MMMM yyyy, EEEE HH:mm').format(widget.entry.date),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
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
              if (_selectedImage != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (widget.entry.imageUrls.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
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
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Fotoğrafı Değiştir'),
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
