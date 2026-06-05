import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/chat.dart';
import 'auth_service.dart';

class ChatService {
  final _auth = AuthService();

  Future<ChatIncidente> cargarHistorial(int idIncidente) async {
    final token = await _obtenerToken();
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/chat/incidentes/$idIncidente/mensajes',
    ).replace(queryParameters: {'token': token});

    final response = await http.get(uri);
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return ChatIncidente.fromJson(Map<String, dynamic>.from(data));
    }

    throw Exception(_mensajeError(data, 'No se pudo cargar el chat'));
  }

  Future<WebSocketChannel> conectarWebSocket(int idIncidente) async {
    final token = await _obtenerToken();
    final uri = _webSocketUri(idIncidente, token);
    return WebSocketChannel.connect(uri);
  }

  String encodeMensaje(String mensaje) {
    return jsonEncode({
      'mensaje': mensaje,
      'tipo_mensaje': 'texto',
    });
  }

  Uri _webSocketUri(int idIncidente, String token) {
    final base = Uri.parse(AppConfig.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/chat/ws/incidentes/$idIncidente',
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
