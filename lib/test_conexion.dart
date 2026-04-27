import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testConexion() async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.0.4:8000/health'),
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
