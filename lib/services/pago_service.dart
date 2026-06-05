import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/pago.dart';
import 'auth_service.dart';

class PagoService {
  final _auth = AuthService();

  Future<ResumenCobro> obtenerResumen(int idIncidente) async {
    final token = await _obtenerToken();
    final response = await http.get(
      _uri('/pagos/incidentes/$idIncidente/resumen', token),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return ResumenCobro.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo cargar el cobro'));
  }

  Future<ResumenCobro> aceptarMonto(int idIncidente) async {
    final token = await _obtenerToken();
    final response = await http.put(
      _uri('/pagos/incidentes/$idIncidente/aceptar', token),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return ResumenCobro.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo aceptar el monto'));
  }

  Future<PagoConComprobante> registrarPago({
    required int idIncidente,
    required String metodoPago,
    required String referenciaPago,
  }) async {
    final token = await _obtenerToken();
    final response = await http.post(
      _uri('/pagos/incidentes/$idIncidente/pagar', token),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'metodo_pago': metodoPago,
        'referencia_pago': referenciaPago,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PagoConComprobante.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo registrar el pago'));
  }

  Future<ComprobantePago> obtenerComprobante(int idIncidente) async {
    final token = await _obtenerToken();
    final response = await http.get(
      _uri('/pagos/incidentes/$idIncidente/comprobante', token),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return ComprobantePago.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo cargar el comprobante'));
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
      throw Exception('Sesion no valida. Inicia sesion nuevamente.');
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
