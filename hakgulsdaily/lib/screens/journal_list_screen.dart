import 'package:flutter/material.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:hakgulsdaily/main.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlüklerim'),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Lütfen giriş yapın.'));
    }

    final journalEntriesStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journal_entries')
        .orderBy('date', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: journalEntriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz günlük girdiniz yok.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final entry =
                JournalEntry.fromJson(doc.data() as Map<String, dynamic>);
            entry.docId = doc.id;

            return Dismissible(
              key: Key(doc.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Günlüğü Sil'),
                    content: const Text(
                        'Bu günlüğü silmek istediğinizden emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Sil',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (direction) async {
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('journal_entries')
                    .doc(doc.id)
                    .delete();
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Günlük silindi.')),
                );
              },
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                title: Text(entry.text),
                subtitle: Text(
                    DateFormat('dd MMMM yyyy, HH:mm').format(entry.date)),
                trailing: Text('${entry.score ?? ''}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => JournalDetailScreen(
                        entry: entry,
                        collectionPath: 'users/${user.uid}/journal_entries',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
