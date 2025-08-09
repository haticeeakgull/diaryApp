import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final TextEditingController _usernameController = TextEditingController();
  String? _profilePhotoUrl;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Kullanıcı verilerini Firestore'dan çekme
  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            _usernameController.text = data['username'] ?? '';
            _profilePhotoUrl = data['photoUrl'];
            setState(() {});
          }
        }
      } catch (e) {
        print('DEBUG: Kullanıcı verisi çekilirken hata oluştu: $e');
      }
    }
  }

  // Galeri'den fotoğraf seçme
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Profil bilgilerini ve fotoğrafı kaydetme
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    String? newPhotoUrl = _profilePhotoUrl;

    if (_selectedImage != null) {
      // Fotoğraf yükleniyor
      try {
        final storageRef = _storage.ref().child('user_profile_photos').child(user.uid);
        await storageRef.putFile(_selectedImage!);
        newPhotoUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('DEBUG: Profil fotoğrafı yüklenirken hata oluştu: $e');
        // Hata durumunda yüklemeyi iptal et
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Firestore'da kullanıcı bilgilerini güncelleme
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'username': _usernameController.text,
        'email': user.email,
        'photoUrl': newPhotoUrl,
      }, SetOptions(merge: true));
      _profilePhotoUrl = newPhotoUrl;
    } catch (e) {
      print('DEBUG: Profil bilgileri kaydedilirken hata oluştu: $e');
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil başarıyla güncellendi!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!) as ImageProvider
                            : (_profilePhotoUrl != null
                                ? NetworkImage(_profilePhotoUrl!)
                                : null),
                        child: _selectedImage == null && _profilePhotoUrl == null
                            ? const Icon(Icons.person, size: 80, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 20,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.camera_alt, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue[600],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Profili Kaydet',
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
