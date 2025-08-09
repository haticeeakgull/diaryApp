import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart'; // JournalDetailScreen'i doğru şekilde çağıracağız
import 'package:intl/intl.dart';

class SharedEntriesScreen extends StatefulWidget {
  const SharedEntriesScreen({super.key});

  @override
  State<SharedEntriesScreen> createState() => _SharedEntriesScreenState();
}

class _SharedEntriesScreenState extends State<SharedEntriesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

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
      appBar: AppBar(
        title: const Text('Paylaşılan Günlükler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final entry = JournalEntry.fromJson(doc.data() as Map<String, dynamic>);
              entry.docId = doc.id;

              // Null kontrolü eklendi
              final authorId = doc['authorId'] as String?;
              final authorText = authorId == null
                  ? 'Bilinmeyen yazar'
                  : (authorId == user.uid ? 'Siz' : 'Başka bir kullanıcı');

              return ListTile(
                title: Text(entry.text),
                subtitle: Text('Yazar: $authorText'),
                trailing: Text(DateFormat('dd MMM').format(entry.date)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => JournalDetailScreen(
                        entry: entry,
                        collectionPath: 'shared_journals',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
