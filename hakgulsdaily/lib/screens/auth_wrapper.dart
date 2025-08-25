import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/screens/home_screen.dart'; 
import 'package:hakgulsdaily/screens/auth_screen.dart'; 
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // FirebaseAuth.instance.authStateChanges() kullanıcının giriş yapıp yapmadığını takip eder.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Eğer bağlantı kurulurken bekleniyorsa, bir yüklenme animasyonu göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Eğer bir kullanıcı giriş yapmışsa (snapshot.hasData true ise), HomeScreen'i göster
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        // Kullanıcı giriş yapmamışsa, AuthScreen'i göster
        return const AuthScreen();
      },
    );
  }
}
