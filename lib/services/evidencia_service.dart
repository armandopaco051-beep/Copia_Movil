import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class EvidenciaService {
  final AuthService _auth = AuthService();

  Map<String, dynamic> _procesarRespuesta({
    required int statusCode,
    required String body,
    required String mensajeError,
  }) {
    try {
      final data = body.isNotEmpty ? jsonDecode(body) : {};

      if (statusCode == 200 || statusCode == 201) {
        return {
          'ok': true,
          'data': data,
        };
      }

      return {
        'ok': false,
        'error': data['detail'] ?? data['error'] ?? mensajeError,
      };
    } catch (e) {
      return {
        'ok': false,
        'error': '$mensajeError. Respuesta no válida: $body',
      };
    }
  }

  // ============================================================
  // ✅ NUEVO: subir muchas imágenes, muchos audios y texto juntos
  // Backend:
  // POST /evidencias/multimedia/{id_incidente}
  // Campos:
  // imagenes, audios, texto
  // ============================================================
  Future<Map<String, dynamic>> subirMultimedia({
    required int idIncidente,
    List<File> imagenes = const [],
    List<File> audios = const [],
    String texto = '',
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/multimedia/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ✅ CAMBIO: el nombre "texto" debe coincidir con FastAPI
      if (texto.trim().isNotEmpty) {
        request.fields['texto'] = texto.trim();
      }

      // ✅ CAMBIO: el nombre "imagenes" debe coincidir con FastAPI
      for (final imagen in imagenes) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'imagenes',
            imagen.path,
          ),
        );
      }

      // ✅ CAMBIO: el nombre "audios" debe coincidir con FastAPI
      for (final audio in audios) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audios',
            audio.path,
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('MULTIMEDIA STATUS: ${response.statusCode}');
      print('MULTIMEDIA BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir evidencias multimedia',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir evidencias multimedia: $e',
      };
    }
  }

  // ============================================================
  // SUBIR UNA IMAGEN
  // Backend:
  // POST /evidencias/imagen/{id_incidente}
  // Campo:
  // archivo
  // ============================================================
  Future<Map<String, dynamic>> subirImagen({
    required int idIncidente,
    required File imagen,
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/imagen/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ✅ Se mantiene "archivo" porque tu backend separado usa archivo
      request.files.add(
        await http.MultipartFile.fromPath(
          'archivo',
          imagen.path,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('IMAGEN STATUS: ${response.statusCode}');
      print('IMAGEN BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir la imagen',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir la imagen: $e',
      };
    }
  }

  // ============================================================
  // SUBIR MUCHAS IMÁGENES AL ENDPOINT SEPARADO
  // Backend:
  // POST /evidencias/imagen/{id_incidente}
  // Campo repetido:
  // archivo
  // ============================================================
  Future<Map<String, dynamic>> subirImagenes({
    required int idIncidente,
    required List<File> imagenes,
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/imagen/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ✅ CAMBIO: varias imágenes usando el mismo campo "archivo"
      for (final imagen in imagenes) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'archivo',
            imagen.path,
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('IMAGENES STATUS: ${response.statusCode}');
      print('IMAGENES BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir las imágenes',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir las imágenes: $e',
      };
    }
  }

  // ============================================================
  // SUBIR UN AUDIO
  // Backend:
  // POST /evidencias/audio/{id_incidente}
  // Campo:
  // archivo
  // ============================================================
  Future<Map<String, dynamic>> subirAudio({
    required int idIncidente,
    required File audio,
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/audio/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'archivo',
          audio.path,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('AUDIO STATUS: ${response.statusCode}');
      print('AUDIO BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir el audio',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir el audio: $e',
      };
    }
  }

  // ============================================================
  // SUBIR MUCHOS AUDIOS AL ENDPOINT SEPARADO
  // Backend:
  // POST /evidencias/audio/{id_incidente}
  // Campo repetido:
  // archivo
  // ============================================================
  Future<Map<String, dynamic>> subirAudios({
    required int idIncidente,
    required List<File> audios,
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/audio/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      for (final audio in audios) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'archivo',
            audio.path,
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('AUDIOS STATUS: ${response.statusCode}');
      print('AUDIOS BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir los audios',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir los audios: $e',
      };
    }
  }

  // ============================================================
  // SUBIR TEXTO
  // Backend:
  // POST /evidencias/texto/{id_incidente}
  // Campo:
  // descripcion
  // ============================================================
  Future<Map<String, dynamic>> subirTexto({
    required int idIncidente,
    required String descripcion,
  }) async {
    try {
      final token = await _auth.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/evidencias/texto/$idIncidente'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['descripcion'] = descripcion.trim();

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print('TEXTO STATUS: ${response.statusCode}');
      print('TEXTO BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al subir el texto',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al subir el texto: $e',
      };
    }
  }

  // ============================================================
  // PROCESAR CON IA
  // ============================================================
  Future<Map<String, dynamic>> procesarConIA(int idIncidente) async {
    try {
      final token = await _auth.getToken();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/ia/procesar-incidente/$idIncidente'),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      final body = utf8.decode(response.bodyBytes);

      print('IA STATUS: ${response.statusCode}');
      print('IA BODY: $body');

      return _procesarRespuesta(
        statusCode: response.statusCode,
        body: body,
        mensajeError: 'Error al procesar con IA',
      );
    } catch (e) {
      return {
        'ok': false,
        'error': 'Error al procesar con IA: $e',
      };
    }
  }
}
