import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/usuario.dart';

class AuthService {
  static const _tokenKey = 'token';
  static const _usuarioKey = 'usuario';

  Future<Map<String, dynamic>> registro({
    required String codigo,
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    required String telefono,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'codigo': codigo,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'password': contrasena,
        'telefono': telefono,
        'id_rol': 4,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 201) {
      return {'ok': true, 'data': data};
    }

    return {'ok': false, 'error': data['detail'] ?? 'Error al registrarse'};
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': contrasena,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, data['access_token']);
      await prefs.setString(_usuarioKey, jsonEncode(data['usuario']));
      return {'ok': true, 'data': data};
    }

    return {'ok': false, 'error': data['detail'] ?? 'Credenciales incorrectas'};
  }

  Future<Map<String, dynamic>> recuperarPassword(String email) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/recuperar-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) return {'ok': true};
    return {'ok': false, 'error': data['detail'] ?? 'Error'};
  }

  Future<Map<String, dynamic>> cambiarPassword({
    required String email,
    required String nuevaContrasena,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/auth/cambiar-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'nueva_password': nuevaContrasena,
      }),
    );

    if (response.statusCode == 200) return {'ok': true};

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return {'ok': false, 'error': data['detail'] ?? 'Error'};
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usuarioKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Usuario?> getUsuarioActual() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_usuarioKey);
    if (str == null) return null;
    return Usuario.fromJson(jsonDecode(str));
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> actualizarPerfil({
    // ✅ CAMBIO: de int a String
    required String codigo,
    required Map<String, dynamic> datos,
  }) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/usuarios/$codigo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(datos),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usuarioKey, jsonEncode(data));
      return {'ok': true, 'data': data};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Error'};
  }
}
