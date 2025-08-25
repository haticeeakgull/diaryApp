import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  // Firestore'dan bir günlük girişini silmek için yeni bir fonksiyon.
  Future<void> _deleteJournalEntry(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users/${user.uid}/journal_entries')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günlük girişi başarıyla silindi.'),
          backgroundColor: Color.fromARGB(255, 80, 130, 80),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Günlük silinirken bir hata oluştu: $e'),
          backgroundColor: const Color.fromARGB(255, 185, 85, 80),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
      appBar: AppBar(
        title: const Text('Günlükleriniz'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar'ı şeffaf yapıyoruz
      ),
      extendBodyBehindAppBar: true, // App bar arkasına doğru gövdeyi uzat
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users/${user.uid}/journal_entries')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Henüz bir günlük girişi yok.'));
            }

            final journals = snapshot.data!.docs.map((doc) {
              final entry = JournalEntry.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
              return entry;
            }).toList();

            return ListView.builder(
              itemCount: journals.length,
              itemBuilder: (context, index) {
                final entry = journals[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(
                      entry.text.length > 50
                          ? '${entry.text.substring(0, 50)}...'
                          : entry.text,
                    ),
                    subtitle: Text(entry.date.toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Color.fromARGB(255, 185, 85, 80)),
                      onPressed: () {
                        // Silme işleminden önce kullanıcıya onay soran bir diyalog göster.
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Günlüğü Sil'),
                            content: const Text('Bu günlük girişini kalıcı olarak silmek istediğinizden emin misiniz?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('İptal'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                },
                              ),
                              TextButton(
                                child: const Text('Sil'),
                                onPressed: () {
                                  Navigator.of(ctx).pop(); // Diyalogu kapat
                                  if (entry.docId != null) {
                                    _deleteJournalEntry(entry.docId!);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => JournalDetailScreen(
                            entry: entry,
                            collectionPath: ('users/${user.uid}/journal_entries'),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
