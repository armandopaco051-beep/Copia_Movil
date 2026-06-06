import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/cotizacion_express.dart';
import 'auth_service.dart';

class CotizacionExpressException implements Exception {
  final int statusCode;
  final String message;

  CotizacionExpressException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class CotizacionExpressService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw CotizacionExpressException(
        401,
        'Sesion vencida. Inicia sesion nuevamente.',
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<SolicitudCotizacion>> consultarOfertas(
    int idIncidente,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/cotizaciones/incidentes/$idIncidente',
      ),
      headers: await _headers(),
    );

    final data = _decode(response);
    if (response.statusCode == 200 && data is List) {
      return data
          .whereType<Map>()
          .map((e) => SolicitudCotizacion.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList()
        ..sort((a, b) => b.ronda.compareTo(a.ronda));
    }

    throw _exception(response.statusCode, data);
  }

  Future<AceptacionCotizacion> aceptarOferta(int idOferta) async {
    final response = await http.put(
      Uri.parse(
        '${AppConfig.baseUrl}/cotizaciones/ofertas/$idOferta/aceptar',
      ),
      headers: await _headers(),
    );

    final data = _decode(response);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map) {
      return AceptacionCotizacion.fromJson(
        Map<String, dynamic>.from(data),
      );
    }

    throw _exception(response.statusCode, data);
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'detail': body};
    }
  }

  CotizacionExpressException _exception(int statusCode, dynamic data) {
    final detail = data is Map && data['detail'] != null
        ? data['detail'].toString()
        : null;

    switch (statusCode) {
      case 400:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'La solicitud de cotizacion no es valida.',
        );
      case 401:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'Sesion vencida. Inicia sesion nuevamente.',
        );
      case 403:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'No tienes permiso para consultar esta cotizacion.',
        );
      case 404:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'Todavia no existen cotizaciones para este incidente.',
        );
      case 409:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'La oferta ya no esta disponible o ya fue aceptada.',
        );
      default:
        return CotizacionExpressException(
          statusCode,
          detail ?? 'No se pudo procesar la cotizacion.',
        );
    }
  }
}
