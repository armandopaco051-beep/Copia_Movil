import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testConexion() async {
  try {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/health'),
      // Cambiá por tu IP si usás celular físico
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Backend conectado: ${data['estado']}');
    } else {
      print('❌ Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Sin conexión: $e');
  }
}
