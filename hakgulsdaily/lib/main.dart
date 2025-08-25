import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hakgulsdaily/screens/auth_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ScaffoldMessengerState için GlobalKey tanımlıyoruz.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Flutter'ın widget bağlama işlemini başlatıyoruz. Bu her zaman ilk satır olmalı.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Önce Firebase'i başlatın. Bu, diğer tüm servislerin doğru çalışması için kritik.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Şimdi ortam değişkenlerini (API anahtarı vb.) yükleyebilirsiniz.
  await dotenv.load(fileName: ".env");

  // Uygulamayı başlatıyoruz.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Uygulamanın başlığı
      title: 'hakgulsdaily',
      
      // Uygulamanın temasını belirliyoruz.
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      
      // Uygulamada desteklenen dilleri ve yerelleştirme delegelerini belirliyoruz.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // İngilizce
        Locale('tr', ''), // Türkçe
      ],
      
      // GlobalKey'i MaterialApp'in scaffoldMessengerKey parametresine atıyoruz.
      scaffoldMessengerKey: scaffoldMessengerKey,
      
      // Uygulamanın başlangıç sayfası.
      home: const AuthWrapper(),
    );
  }
}