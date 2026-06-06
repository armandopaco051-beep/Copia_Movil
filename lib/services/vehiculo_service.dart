import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/vehiculo.dart';
import 'auth_service.dart';

class VehiculoService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay token. Inicia sesion nuevamente.');
    }

    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Vehiculo>> listarMisVehiculos() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/mis-vehiculos'),
      headers: await _headers(),
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
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'marca': marca,
        'modelo': modelo,
        'placa': placa,
        'anio': anio,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'ok': true, 'data': data};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Error al crear vehículo'};
  }

  Future<Map<String, dynamic>> actualizar({
    required int codigo,
    required Map<String, dynamic> datos,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/$codigo'),
      headers: await _headers(json: true),
      body: jsonEncode(datos),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false, 'error': data['detail'] ?? 'Error'};
  }

  Future<Map<String, dynamic>> eliminar(int codigo) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/vehiculos/$codigo'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false, 'error': 'Error al eliminar'};
  }
}
