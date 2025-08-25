import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini API'den günlük metni için yapıcı ve motive edici geri bildirim alır.
/// Geçici 503 hataları için otomatik tekrar deneme mekanizması içerir.
///
/// [text] parametresi, analiz edilecek günlük metnini içerir.
Future<String> getAiFeedback(String text) async {
  // ÖNEMLİ: API anahtarınızı aşağıdaki boş tırnak işaretlerinin arasına yapıştırın.
  final apiKey = dotenv.env['API_KEY'] ?? '';

  const apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  
  if (apiKey.isEmpty) {
    return 'Lütfen API anahtarınızı girin.';
  }

  // İstek için maksimum deneme sayısı ve ilk bekleme süresi
  const maxRetries = 3;
  const initialDelay = Duration(seconds: 2);

  for (int i = 0; i < maxRetries; i++) {
    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": "Aşağıdaki günlük metnini analiz et ve kullanıcıya realistik ama motive edici bir tavsiye  ve yorum ver. : $text"},
          ],
        },
      ],
    };

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final candidates = jsonResponse['candidates'] as List?;

        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
            return content['parts'][0]['text'] ?? 'API yanıtından metin alınamadı.';
          }
        }
        return 'Yanıt formatı beklenmedik. Lütfen API yanıtını kontrol edin.';
      } else if (response.statusCode == 503 && i < maxRetries - 1) {
        // Model meşgulse, tekrar denemeden önce bekle
        print('API Hatası: 503. Tekrar deneniyor... (${i + 1}/$maxRetries)');
        await Future.delayed(initialDelay * (i + 1));
      } else {
        // Diğer hatalar için (veya son deneme başarısız olursa) hata mesajı dön
        print('API Hatası: ${response.statusCode}');
        print('Yanıt: ${response.body}');
        return 'Günlük analizi yapılamadı. Hata kodu: ${response.statusCode}';
      }
    } catch (e) {
      print('İstisna oluştu: $e');
      return 'Günlük analizi sırasında bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.';
    }
  }
  
  // Tüm denemeler başarısız olursa
  return 'Tüm deneme girişimleri başarısız oldu. Lütfen daha sonra tekrar deneyin.';
}
