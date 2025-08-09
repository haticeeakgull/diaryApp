import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hakgulsdaily/screens/auth_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ScaffoldMessengerState için GlobalKey tanımlıyoruz.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hakgulsdaily',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('tr', ''), // Turkish
      ],
      // GlobalKey'i ScaffoldMessenger'a atıyoruz.
      builder: (context, child) {
        return ScaffoldMessenger(
          key: scaffoldMessengerKey,
          child: child!,
        );
      },
      home: const AuthWrapper(),
    );
  }
}
