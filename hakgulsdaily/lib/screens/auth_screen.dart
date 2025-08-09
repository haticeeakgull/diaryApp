import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hakgulsdaily/main.dart'; // main.dart dosyasındaki global key'i import ediyoruz

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Giriş/Kayıt modunu takip etmek için
  bool _isLogin = true;
  
  // Metin alanları için controller'lar
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Yüklenme durumunu takip etmek için
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Giriş veya kayıt işlemini gerçekleştiren fonksiyon
  Future<void> _submitAuthForm() async {
    // E-posta veya şifre boşsa işlemi durdur
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Lütfen e-posta ve şifre alanlarını doldurun.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      if (!mounted) return; // setState çağırmadan önce mounted kontrolü
      setState(() {
        _isLoading = true;
      });

      if (_isLogin) {
        print('DEBUG: Giriş yapma işlemi başlıyor...');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(), // Boşlukları temizle
          password: _passwordController.text.trim(), // Boşlukları temizle
        );
        print('DEBUG: Giriş başarılı!');
        if (!mounted) return; // SnackBar çağırmadan önce mounted kontrolü
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Başarıyla giriş yapıldı!'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('DEBUG: Kayıt olma işlemi başlıyor...');
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), // Boşlukları temizle
          password: _passwordController.text.trim(), // Boşlukları temizle
        );
        print('DEBUG: Kayıt başarılı!');
        if (!mounted) return; // SnackBar çağırmadan önce mounted kontrolü
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Hesap başarıyla oluşturuldu!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('DEBUG: Kimlik doğrulama hatası: ${e.message}');
      if (!mounted) return; // SnackBar çağırmadan önce mounted kontrolü
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Bir hata oluştu.'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      // `setState` çağrılmadan önce widget'ın hala ekranda olup olmadığını kontrol et
      if (!mounted) return; // Buradaki mounted kontrolü kritik
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submitAuthForm,
                        child: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(_isLogin ? 'Yeni hesap oluştur' : 'Zaten hesabım var'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
