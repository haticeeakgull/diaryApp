import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart'; // JournalDetailScreen'i import ettik
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<JournalEntry>> _events = {};

  @override
  void initState() {
    super.initState();
    _fetchJournals();
  }

  void _fetchJournals() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journal_entries')
        .get();

    _events.clear();
    for (var doc in snapshot.docs) {
      // Hata: "DocumentSnapshot<Object?> can't be assigned to the parameter type DocumentSnapshot<Map<String, dynamic>>"
      // Önceki denemede yapılan DocumentSnapshot.fromMap hatası düzeltildi.
      // fromFirestore metodunun doğrudan QueryDocumentSnapshot'u kabul etmesi gerekiyor.
      // Firestore'dan gelen veriyi doğru tipe dönüştürüyoruz.
      final entry = JournalEntry.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      final entryDate = DateTime.utc(entry.date.year, entry.date.month, entry.date.day);
      if (_events[entryDate] == null) {
        _events[entryDate] = [];
      }
      _events[entryDate]!.add(entry);
    }
    setState(() {});
  }

  List<JournalEntry> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Lütfen giriş yapın.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Takvimi'),
        centerTitle: true,
        backgroundColor: Colors.transparent, // AppBar'ı şeffaf yapıyoruz
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // AppBar'ın arkasındaki degradeyi uzatır
      body: Container(
        // Degrade arka planı buraya ekliyoruz
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(219, 239, 247, 1), // soft mavi
              Color.fromRGBO(251, 216, 216, 1), // soft pembe
            ],
          ),
        ),
        child: Column(
          children: [
            TableCalendar(
              locale: 'tr_TR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Color.fromRGBO(251, 216, 216, 1), // Renkleri tema ile uyumlu hale getirdim
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color.fromRGBO(219, 239, 247, 1), // Renkleri tema ile uyumlu hale getirdim
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: _getEventsForDay(_selectedDay ?? DateTime.now()).length,
                itemBuilder: (context, index) {
                  final entry = _getEventsForDay(_selectedDay ?? DateTime.now())[index];
                  return ListTile(
                    title: Text(entry.text.isNotEmpty ? entry.text : "Metin Yok"),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(entry.date)),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
