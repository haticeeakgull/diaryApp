import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/models/journal_entry.dart';
import 'package:hakgulsdaily/screens/journal_detail_screen.dart';

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

  // Firestore'dan günlük verilerini çeken fonksiyon
  void _fetchJournals() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journal_entries')
        .get();

    _events.clear(); // Eski verileri temizle
    for (var doc in snapshot.docs) {
      final entry = JournalEntry.fromJson(doc.data());
      entry.docId = doc.id;
      final entryDate = DateTime.utc(entry.date.year, entry.date.month, entry.date.day);
      if (_events[entryDate] == null) {
        _events[entryDate] = [];
      }
      _events[entryDate]!.add(entry);
    }
    setState(() {});
  }

  // Belirli bir gün için günlükleri döndüren fonksiyon
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
      ),
      body: Column(
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
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.lightBlue,
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
                  title: Text(entry.text),
                  subtitle: Text(entry.date.toString()),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => JournalDetailScreen(
                          entry: entry,
                          // Takvimde seçilen günlükler için doğru koleksiyon yolunu ekledik.
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
    );
  }
}
