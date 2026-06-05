import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/validacion_arribo.dart';
import 'auth_service.dart';

class ValidacionArriboService {
  final _auth = AuthService();

  Future<ValidacionArribo> obtenerCodigo(int idIncidente) async {
    final token = await _auth.getToken();
    final response = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/validacion-arribo/incidente/$idIncidente/codigo',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return ValidacionArribo.fromJson(Map<String, dynamic>.from(data));
    }

    final mensaje = data is Map
        ? data['detail']?.toString() ?? 'No se pudo obtener el codigo'
        : 'No se pudo obtener el codigo';
    throw Exception(mensaje);
  }
}
