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
          duration: const Duration(seconds: 5),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // AppBar'ın arka planı şeffaf olsun diye
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
             Color.fromRGBO(219, 239, 247, 1), // Soft yeşil
             Color.fromRGBO(251, 216, 216, 1), // Soft pembe
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding'i yatayda artırarak Card'ı genişletiyoruz
              child: Card(
                color: Colors.white, // Card'ı transparan hale getiriyoruz
                elevation: 8.0, // Formun etrafına gölge ekler
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0), // Kartın kenarlarını yuvarlar
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Sütunun boyutunu içerik kadar ayarlar
                    children: [
                      // Logo widget'ını buraya ekliyoruz
                      Image.asset(
                        'assets/logo.jpeg', // Logo dosyanızın yolu
                        height: 350, // İsteğe bağlı olarak logo boyutu ayarlanabilir
                      ),
                      const SizedBox(height: 32), // Logo ile form arasına boşluk bırakır
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-posta',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Container(
                              width: double.infinity, // Butonu genişletir
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color.fromRGBO(219, 239, 247, 1), // Soft yeşil
                                    Color.fromRGBO(251, 216, 216, 1),
                                  ],
                                ),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, // Gradyan için şeffaf yapar
                                  shadowColor: Colors.transparent, // Gölgeyi kaldırır
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                ),
                                onPressed: _submitAuthForm,
                                child: Text(
                                  _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 11, 11, 11),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
          ),
        ),
      ),
    );
  }
}
