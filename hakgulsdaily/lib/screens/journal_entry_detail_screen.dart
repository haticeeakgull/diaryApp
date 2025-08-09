import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:intl/intl.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart'; // Yeni düzenleme ekranını import ediyoruz

class JournalEntryDetailScreen extends StatefulWidget {
  final String entryId;
  final JournalEntry entry;

  const JournalEntryDetailScreen({
    super.key,
    required this.entryId,
    required this.entry,
  });

  @override
  State<JournalEntryDetailScreen> createState() => _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState extends State<JournalEntryDetailScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Günlüğü başka bir kullanıcıyla paylaşma
  Future<void> _shareJournalEntry() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final targetEmail = _emailController.text.trim();
    if (targetEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir e-posta adresi girin.')),
        );
      }
      return;
    }

    try {
      // Hedef kullanıcının UID'sini e-posta adresinden bulma
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belirtilen e-posta adresine sahip kullanıcı bulunamadı.')),
          );
        }
        return;
      }

      final targetUserDoc = usersSnapshot.docs.first;
      final targetUserId = targetUserDoc.id;

      // Günlük girdisini hedef kullanıcıyla paylaşma
      // Hedef kullanıcının 'shared_journals' koleksiyonuna bir referans ekliyoruz
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('shared_journals')
          .doc(widget.entryId)
          .set(widget.entry.toJson());

      // Kendi günlük girdimizde kiminle paylaştığımızı kaydetme
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .doc(widget.entryId)
          .update({
            'sharedWith': FieldValue.arrayUnion([targetUserId]),
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetEmail ile günlük başarıyla paylaşıldı!')),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım sırasında hata oluştu: $e')),
        );
      }
    }
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Günlüğü Paylaş'),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Kullanıcının E-posta Adresi',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                _shareJournalEntry();
                Navigator.of(ctx).pop();
              },
              child: const Text('Paylaş'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => JournalDetailScreen(
                    
                    entry: widget.entry,
                    collectionPath: 'users/${FirebaseAuth.instance.currentUser!.uid}/journal_entries',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showShareDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd MMMM yyyy, EEEE HH:mm', 'tr_TR').format(widget.entry.date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.entry.imageUrls.isNotEmpty)
                ...widget.entry.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  ),
                )).toList(),
              Text(
                widget.entry.text,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (widget.entry.score != null)
                Text(
                  'Günün Puanı: ${_getScoreEmoji(widget.entry.score!)}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (widget.entry.artisticActivity != null)
                Text('Sanatsal: ${widget.entry.artisticActivity}', style: const TextStyle(fontSize: 16)),
              if (widget.entry.sportiveActivity != null)
                Text('Sportif: ${widget.entry.sportiveActivity}', style: const TextStyle(fontSize: 16)),
              if (widget.entry.academicActivity != null)
                Text('Akademik: ${widget.entry.academicActivity}', style: const TextStyle(fontSize: 16)),
              if (widget.entry.socialActivity != null)
                Text('Sosyal: ${widget.entry.socialActivity}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  String _getScoreEmoji(int score) {
    switch (score) {
      case 1: return '😊';
      case 2: return '😐';
      case 3: return '😔';
      case 4: return '😡';
      default: return '';
    }
  }
}
