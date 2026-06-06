import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/app_config.dart';

Future<void> testConexion() async {
  try {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/health'),
      //Uri.parse('${AppConfig.baseUrl}/health'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Backend conectado: ${data['estado']}');
    } else {
      print('❌ Error del backend: ${response.statusCode}');
      print('Respuesta: ${response.body}');
    }
  } catch (e) {
    print('❌ Sin conexión: $e');
  }
}
