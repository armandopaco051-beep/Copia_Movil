import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/tracking.dart';
import 'auth_service.dart';

class TrackingService {
  final _auth = AuthService();

  Future<EtaTracking> obtenerEta(
    int idIncidente, {
    double? velocidadPromedioKmh,
  }) async {
    final token = await _auth.getToken();
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/tracking/incidente/$idIncidente/eta',
    ).replace(
      queryParameters: velocidadPromedioKmh == null
          ? null
          : {
              'velocidad_promedio_kmh':
                  velocidadPromedioKmh.toStringAsFixed(0),
            },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return EtaTracking.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo calcular el ETA'));
  }

  Future<UltimaUbicacionTecnico> obtenerUltimaUbicacion(
    int idIncidente,
  ) async {
    final token = await _auth.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/tracking/incidente/$idIncidente/ultima'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return UltimaUbicacionTecnico.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(
      _mensajeError(data, 'No se pudo obtener la ubicacion del tecnico'),
    );
  }

  String _mensajeError(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }
}
