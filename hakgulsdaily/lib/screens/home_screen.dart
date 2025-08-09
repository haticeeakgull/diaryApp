import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_list_screen.dart';
import 'package:hakgulsdaily/screens/profile_screen.dart';
import 'package:hakgulsdaily/screens/calendar_screen.dart'; // Takvim sayfasını import ediyoruz
import 'package:hakgulsdaily/screens/shared_entries_screen.dart'; // Yeni paylaşılan günlükler ekranını import ediyoruz
import 'package:hakgulsdaily/main.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:firebase_storage/firebase_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _artisticController = TextEditingController();
  final TextEditingController _sportiveController = TextEditingController();
  final TextEditingController _academicController = TextEditingController();
  final TextEditingController _socialController = TextEditingController();
  int? _selectedScore;
  File? _selectedImage;

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
      print('DEBUG: Fotoğraf seçildi: ${pickedFile.path}');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçildi, şimdi kaydedebilirsiniz.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('DEBUG: Fotoğraf seçimi iptal edildi.');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçimi iptal edildi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveJournalEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Kayıt yapmak için lütfen giriş yapın.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_textController.text.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir şeyler yazın.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        print('DEBUG: Fotoğraf Firebase Storage\'a yükleniyor...');
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('journal_images')
            .child(user.uid)
            .child('${DateTime.now().toIso8601String()}.jpg');

        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
        print('DEBUG: Fotoğraf URL\'si alındı: $imageUrl');
      } on FirebaseException catch (e) {
        print('DEBUG: Firebase Storage hatası: ${e.code} - ${e.message}');
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenirken Firebase hatası oluştu: ${e.message}'),
            duration: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        print('DEBUG: Fotoğraf yüklenirken genel hata oluştu: $e');
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenirken beklenmedik bir hata oluştu: $e'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    final newEntry = JournalEntry(
      text: _textController.text,
      score: _selectedScore,
      date: DateTime.now(),
      imageUrls: imageUrl != null ? [imageUrl] : [],
      artisticActivity: _artisticController.text.isNotEmpty ? _artisticController.text : null,
      sportiveActivity: _sportiveController.text.isNotEmpty ? _sportiveController.text : null,
      academicActivity: _academicController.text.isNotEmpty ? _academicController.text : null,
      socialActivity: _socialController.text.isNotEmpty ? _socialController.text : null,
      authorId: user.uid, // Günlük kaydını kimin yaptığını belirtmek için yazar ID'sini ekliyoruz
    );

    try {
      print('DEBUG: Günlük kaydetme işlemi başlıyor...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .add(newEntry.toJson());

      print('DEBUG: Günlük başarıyla kaydedildi!');
      
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Günlük kaydedildi!'),
          duration: Duration(seconds: 3),
        ),
      );

      _textController.clear();
      _artisticController.clear();
      _sportiveController.clear();
      _academicController.clear();
      _socialController.clear();
      setState(() {
        _selectedScore = null;
        _selectedImage = null;
      });

    } on FirebaseException catch (e) {
      print('DEBUG: Firestore hatası: ${e.code} - ${e.message}');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Günlük kaydedilirken Firebase hatası oluştu: ${e.message}'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('DEBUG: Kayıt sırasında genel hata oluştu: $e');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Kayıt sırasında beklenmedik bir hata oluştu: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildCategoryTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günün nasıldı?'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const CalendarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const JournalListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group), // Paylaşılan günlükler için yeni ikon
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const SharedEntriesScreen(), // Yeni sayfaya yönlendirme
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
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
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Bugün neler yaptın, neler hissettin?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
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
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Fotoğraf Ekle'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                      onTap: () {
                        setState(() {
                          _selectedScore = i;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedScore == i ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          i == 1 ? '😊' : i == 2 ? '😐' : i == 3 ? '😔' : '😡',
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
                labelText: 'Sanatsal Etkinlik (örn: Resim yaptım, piyano çaldım)',
                icon: Icons.palette,
              ),
              _buildCategoryTextField(
                controller: _sportiveController,
                labelText: 'Sportif Etkinlik (örn: Koşu, fitness, yüzme)',
                icon: Icons.sports_soccer,
              ),
              _buildCategoryTextField(
                controller: _academicController,
                labelText: 'Akademik Etkinlik (örn: Ders çalıştım, makale okudum)',
                icon: Icons.school,
              ),
              _buildCategoryTextField(
                controller: _socialController,
                labelText: 'Sosyal Etkinlik (örn: Arkadaşlarımla buluştum, etkinliğe katıldım)',
                icon: Icons.people,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveJournalEntry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue[600],
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
