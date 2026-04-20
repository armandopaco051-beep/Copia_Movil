import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/incidente.dart';
import 'auth_service.dart';

class IncidenteService {
  final _auth = AuthService();

  Future<Map<String, dynamic>> crear({
    required String descripcion,
    required double latitud,
    required double longitud,
    required int idVehiculo,
    required int idCategoria,
    // ✅ CAMBIO: codigoUsuario de int a String
    required String codigoUsuario,
  }) async {
    final token = await _auth.getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/incidentes/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'descripcion': descripcion,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_reporte': DateTime.now().toIso8601String(),
        'id_prioridad': 2,
        'id_categoria_problema': idCategoria,
        'id_estado_incidente': 1,
        'id_vehiculo': idVehiculo,
        'codigo_usuario': codigoUsuario,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201) return {'ok': true, 'data': data};
    return {'ok': false, 'error': data['detail'] ?? 'Error al reportar'};
  }

  // ✅ CAMBIO: codigoUsuario de int a String
  Future<List<Incidente>> historialUsuario(String codigoUsuario) async {
    final token = await _auth.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/incidentes/usuario/$codigoUsuario'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => Incidente.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> cancelar(int codigo) async {
    final token = await _auth.getToken();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/incidentes/$codigo/cancelar'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false};
  }
}
