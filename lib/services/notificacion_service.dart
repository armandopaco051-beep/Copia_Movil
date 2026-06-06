import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/notificacion.dart';
import 'auth_service.dart';

class NotificacionService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion no valida. Inicia sesion nuevamente.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<int> contarNoLeidas() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/notificaciones/no-leidas/contador'),
      headers: await _headers(),
    );

    final data = _decode(response);
    if (response.statusCode == 200) {
      return _extraerContador(data);
    }
    throw Exception(_mensajeError(data, 'No se pudo cargar el contador'));
  }

  Future<List<NotificacionCliente>> listar({
    bool soloNoLeidas = false,
    int? limit,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/notificaciones/mis-notificaciones',
    ).replace(
      queryParameters: {
        if (soloNoLeidas) 'solo_no_leidas': 'true',
        if (limit != null) 'limit': limit.toString(),
      },
    );

    final response = await http.get(uri, headers: await _headers());
    final data = _decode(response);

    if (response.statusCode == 200 && data is List) {
      return data
          .map((e) => NotificacionCliente.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }
    throw Exception(_mensajeError(data, 'No se pudieron cargar notificaciones'));
  }

  Future<void> marcarComoLeida(int codigo) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/notificaciones/$codigo/leer'),
      headers: await _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = _decode(response);
    throw Exception(_mensajeError(data, 'No se pudo marcar como leida'));
  }

  Future<void> marcarTodasComoLeidas() async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/notificaciones/marcar-todas/leidas'),
      headers: await _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = _decode(response);
    throw Exception(_mensajeError(data, 'No se pudieron marcar como leidas'));
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  int _extraerContador(dynamic data) {
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is Map) {
      for (final key in [
        'contador',
        'count',
        'total',
        'no_leidas',
        'notificaciones_no_leidas',
        'data',
      ]) {
        final value = data[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  String _mensajeError(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }
}
