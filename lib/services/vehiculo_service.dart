import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/vehiculo.dart';
import 'auth_service.dart';

class VehiculoService {
  final _auth = AuthService();

  // ✅ CAMBIO: idUsuario de int a String
  Future<List<Vehiculo>> listarPorUsuario(String idUsuario) async {
    final token = await _auth.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/usuario/$idUsuario'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => Vehiculo.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> crear({
    required String marca,
    required String modelo,
    required String placa,
    required String anio,
    // ✅ CAMBIO: idUsuario de int a String
    required String idUsuario,
  }) async {
    final token = await _auth.getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'marca': marca,
        'modelo': modelo,
        'placa': placa,
        'año': anio,
        'id_usuario': idUsuario,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201) return {'ok': true, 'data': data};
    return {'ok': false, 'error': data['detail'] ?? 'Error al crear vehículo'};
  }

  Future<Map<String, dynamic>> actualizar({
    required int codigo,
    required Map<String, dynamic> datos,
  }) async {
    final token = await _auth.getToken();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/$codigo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(datos),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false, 'error': data['detail'] ?? 'Error'};
  }

  Future<Map<String, dynamic>> eliminar(int codigo) async {
    final token = await _auth.getToken();
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/$codigo'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false, 'error': 'Error al eliminar'};
  }
}
