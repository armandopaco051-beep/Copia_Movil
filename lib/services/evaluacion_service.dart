import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/evaluacion.dart';
import 'auth_service.dart';

class EvaluacionServiceException implements Exception {
  final int statusCode;
  final String message;

  EvaluacionServiceException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class EvaluacionService {
  final _auth = AuthService();

  Future<EvaluacionServicio> consultar(int idIncidente) async {
    final token = await _obtenerToken();
    final response = await http.get(
      _uri('/evaluaciones/incidentes/$idIncidente', token),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return EvaluacionServicio.fromJson(Map<String, dynamic>.from(data));
    }

    throw EvaluacionServiceException(
      response.statusCode,
      _mensajeError(data, 'Evaluacion no encontrada'),
    );
  }

  Future<EvaluacionRegistrada> crear({
    required int idIncidente,
    required int calificacion,
    required String comentario,
    required int puntualidad,
    required int trato,
    required int solucion,
    required int precio,
  }) async {
    final token = await _obtenerToken();
    final response = await http.post(
      _uri('/evaluaciones/incidentes/$idIncidente', token),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'calificacion': calificacion,
        'comentario': comentario,
        'puntualidad': puntualidad,
        'trato': trato,
        'solucion': solucion,
        'precio': precio,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return EvaluacionRegistrada.fromJson(Map<String, dynamic>.from(data));
    }

    throw EvaluacionServiceException(
      response.statusCode,
      _mensajeError(data, 'No se pudo registrar la evaluacion'),
    );
  }

  Uri _uri(String path, String token) {
    return Uri.parse(AppConfig.baseUrl).replace(
      path: path,
      queryParameters: {'token': token},
    );
  }

  Future<String> _obtenerToken() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw EvaluacionServiceException(
        401,
        'Sesion no valida. Inicia sesion nuevamente.',
      );
    }
    return token;
  }

  String _mensajeError(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }
}
