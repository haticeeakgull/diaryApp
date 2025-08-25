import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart';
import 'package:intl/intl.dart';

class SharedEntriesScreen extends StatefulWidget {
  const SharedEntriesScreen({super.key});

  @override
  State<SharedEntriesScreen> createState() => _SharedEntriesScreenState();
}

class _SharedEntriesScreenState extends State<SharedEntriesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser!;

  Future<void> _deleteJournalEntry(String docId) async {
    try {
      await _firestore
          .collection('shared_journals')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paylaşılan günlük başarıyla silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Günlük silinirken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: const Text('Bu paylaşılan günlüğü silmek istediğinizden emin misiniz?'),
        actions: <Widget>[
          TextButton(
            child: const Text('İptal'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          ElevatedButton(
            onPressed: () {
              _deleteJournalEntry(docId);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paylaşılan Günlükler')),
        body: const Center(child: Text('Lütfen giriş yapın.')),
      );
    }

    final sharedJournalsStream = _firestore
        .collection('shared_journals')
        .where('recipientId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
      appBar: AppBar(
        title: const Text('Paylaşılan Günlükler'),
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
          stream: sharedJournalsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Henüz sizinle paylaşılan bir günlük yok.'));
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final entry = JournalEntry.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);

                final authorId = doc['authorId'] as String?;
                final authorText = authorId == null
                    ? 'Bilinmeyen yazar'
                    : (authorId == user.uid ? 'Siz' : 'Başka bir kullanıcı');

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.text.isNotEmpty
                              ? (entry.text.length > 100
                                  ? '${entry.text.substring(0, 100)}...'
                                  : entry.text)
                              : "Metin Yok",
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Yazar: $authorText',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            Text(
                              DateFormat('dd MMM').format(entry.date),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _showDeleteConfirmationDialog(doc.id);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => JournalDetailScreen(
                                      entry: entry,
                                      collectionPath: 'shared_journals',
                                      isEditable: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
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
