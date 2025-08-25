import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hakgulsdaily/screens/profile_screen.dart';
import 'package:hakgulsdaily/screens/calendar_screen.dart';
import 'package:hakgulsdaily/screens/journal_list_screen.dart';
import 'package:hakgulsdaily/screens/shared_entries_screen.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hakgulsdaily/services/ai_analysis_service.dart';
import 'package:hakgulsdaily/screens/ai_feedback_screen.dart';
import 'package:hakgulsdaily/main.dart';

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

// The main home screen widget.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controllers for text input fields.
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _artisticController = TextEditingController();
  final TextEditingController _sportiveController = TextEditingController();
  final TextEditingController _academicController = TextEditingController();
  final TextEditingController _socialController = TextEditingController();

  // State variables for the screen.
  int? _selectedScore;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isProcessing = false;
  bool _isPickingImage = false;

  @override
  void dispose() {
    // Dispose of controllers to free up resources.
    _textController.dispose();
    _artisticController.dispose();
    _sportiveController.dispose();
    _academicController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  // Method to pick an image from the gallery.
  Future<void> _pickImage() async {
    if (_isProcessing) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Kayıt işlemi devam ederken fotoğraf seçilemez.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Read the image file as bytes in a separate isolate to prevent UI freeze
        final imageBytes = await compute(_processImageInIsolate, pickedFile.path);

        if (imageBytes != null) {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = imageBytes;
          });
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf başarıyla seçildi.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf işlenirken bir hata oluştu.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf seçimi iptal edildi.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on Exception catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilirken bir hata oluştu: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isPickingImage = false;
      });
    }
  }

  // Method to remove the selected image from the UI.
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Seçilen fotoğraf kaldırıldı.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Method to save the journal entry to Firebase.
  Future<void> _saveJournalEntry() async {
    if (_isProcessing || _isPickingImage) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Başka bir işlem devam ederken kayıt yapamazsınız.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

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

    setState(() {
      _isProcessing = true;
    });

    try {
      String? imageUrl;
      // 1. Fotoğrafı yükle (eğer varsa)
      if (_selectedImageBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('journal_images')
            .child(user.uid)
            .child('${DateTime.now().toIso8601String()}.jpg');

        await storageRef.putData(_selectedImageBytes!);
        imageUrl = await storageRef.getDownloadURL();
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf başarıyla yüklendi.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 2. AI geri bildirimini al
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Günlük analizi yapılıyor...'),
          duration: Duration(seconds: 2),
        ),
      );
      String aiFeedback = await getAiFeedback(_textController.text);

      // 3. Günlük girdisini Firebase'e kaydet
      final newEntry = JournalEntry(
        text: _textController.text,
        score: _selectedScore,
        date: DateTime.now(),
        imageUrls: imageUrl != null ? [imageUrl] : [],
        artisticActivity: _artisticController.text.isNotEmpty ? _artisticController.text : null,
        sportiveActivity: _sportiveController.text.isNotEmpty ? _sportiveController.text : null,
        academicActivity: _academicController.text.isNotEmpty ? _academicController.text : null,
        socialActivity: _socialController.text.isNotEmpty ? _socialController.text : null,
        authorId: user.uid,
        aiFeedback: aiFeedback,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .add(newEntry.toJson());

      // 4. İşlem başarıyla tamamlandı, arayüzü temizle ve kullanıcıyı yönlendir
      _textController.clear();
      _artisticController.clear();
      _sportiveController.clear();
      _academicController.clear();
      _socialController.clear();
      setState(() {
        _selectedScore = null;
        _selectedImage = null;
        _selectedImageBytes = null;
      });

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Günlük kaydı başarıyla oluşturuldu.'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => AiFeedbackScreen(
            feedback: aiFeedback,
          ),
        ),
      );

    } on FirebaseException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Firebase hatası: ${e.message}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } on Exception catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      // İşlem tamamlandığında her zaman durumu sıfırla
      setState(() {
        _isProcessing = false;
      });
    }
  }


  // Method to show a sign out confirmation dialog.
  void _signOut() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Çıkış Onayı'),
          content: const Text('Uygulamadan çıkış yapmak istediğinize emin misiniz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog.
              },
              child: const Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).pop(); // Close the dialog.
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Başarıyla çıkış yapıldı.')),
                );
              },
              child: const Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build a text field for a category.
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
        backgroundColor: Colors.transparent,
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
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const SharedEntriesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(219, 239, 247, 1),
              Color.fromRGBO(251, 216, 216, 1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 20),
                  if (_selectedImageBytes != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: _removeImage,
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isProcessing || _isPickingImage ? null : _pickImage,
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
                        : const Text('Fotoğraf Ekle'),
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
                              color: _selectedScore == i ? Colors.blue : const Color.fromARGB(255, 255, 255, 255),
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
                    onPressed: _isProcessing ? null : _saveJournalEntry,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue[600],
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Kaydet ve Analiz Et',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
