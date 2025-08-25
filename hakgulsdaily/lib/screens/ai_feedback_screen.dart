import 'package:flutter/material.dart';

// Yapay zeka geri bildirim ekranı
class AiFeedbackScreen extends StatelessWidget {
  final String feedback;
  final String? question;

  const AiFeedbackScreen({
    super.key,
    required this.feedback,
    this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
      appBar: AppBar(
        title: const Text('AI Geri Bildirim'),
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
        child: SingleChildScrollView( // İçeriğin kaydırılabilir olması için eklenen widget
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // Çakışmayı gidermek için üstten boşluk ekle
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 20, // AppBar ve boşluk için yer aç
                ),
                const Text(
                  "Merhaba!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Günlük Analizi:",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          feedback,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (question != null) ...[
                          const SizedBox(height: 20),
                          const Text(
                            "Benim bir sorum var:",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            question!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
