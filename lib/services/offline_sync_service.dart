import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/evidencia_local.dart';
import '../models/incidente_local.dart';
import '../models/sync_conflicto.dart';
import 'auth_service.dart';
import 'evidencia_service.dart';
import 'offline_database_service.dart';

class OfflineSyncResult {
  final int total;
  final int sincronizados;
  final int parciales;
  final int conflictos;
  final int conError;
  final List<String> errores;

  const OfflineSyncResult({
    required this.total,
    required this.sincronizados,
    required this.parciales,
    required this.conflictos,
    required this.conError,
    required this.errores,
  });
}

class _IncidenteSyncResponse {
  final String estadoSync;
  final int? idBackend;
  final int? idConflicto;
  final String? error;

  const _IncidenteSyncResponse({
    required this.estadoSync,
    this.idBackend,
    this.idConflicto,
    this.error,
  });
}

class OfflineSyncService {
  final OfflineDatabaseService _db = OfflineDatabaseService.instance;
  final AuthService _auth = AuthService();
  final EvidenciaService _evidenciaService = EvidenciaService();

  Future<bool> hayConexion() async {
    final estados = await Connectivity().checkConnectivity();
    return estados.any((estado) => estado != ConnectivityResult.none);
  }

  Future<String> guardarIncidenteLocal({
    required String descripcion,
    required double latitud,
    required double longitud,
    required int idVehiculo,
    required int idCategoria,
    required String codigoUsuario,
    bool cotizacionExpress = false,
    List<File> imagenes = const [],
    List<File> audios = const [],
  }) async {
    final idLocal = await _db.generarIdLocal();
    final fecha = DateTime.now().toIso8601String();
    final incidente = IncidenteLocal(
      idLocal: idLocal,
      clienteId: codigoUsuario,
      vehiculoId: idVehiculo,
      categoriaId: idCategoria,
      prioridadId: 2,
      descripcion: descripcion,
      latitud: latitud,
      longitud: longitud,
      fechaCreacionLocal: fecha,
      fechaReporte: fecha,
      estadoLocal: IncidenteLocal.estadoLocalRegistrado,
      estadoSincronizacion: IncidenteLocal.estadoSyncPendiente,
      versionLocal: 1,
      cotizacionExpress: cotizacionExpress,
    );

    await _db.guardarIncidente(
      incidente: incidente,
      imagenes: imagenes,
      audios: audios,
      texto: descripcion,
    );

    return idLocal;
  }

  Future<int> contarPendientes() => _db.contarPendientes();

  Future<List<IncidenteLocal>> listarPendientes() => _db.listarPendientes();

  Future<List<IncidenteLocal>> listarConflictosLocales() {
    return _db.listarPorEstado(IncidenteLocal.estadoSyncConflicto);
  }

  Future<OfflineSyncResult> sincronizarPendientes() async {
    // CU-OFF-08: Sincronizar PENDIENTE, ERROR y SINCRONIZADO_PARCIAL.
    if (!await hayConexion()) {
      return const OfflineSyncResult(
        total: 0,
        sincronizados: 0,
        parciales: 0,
        conflictos: 0,
        conError: 0,
        errores: ['Sin conexion disponible.'],
      );
    }

    final pendientes = await _db.listarParaSincronizar();
    var sincronizados = 0;
    var parciales = 0;
    var conflictos = 0;
    var conError = 0;
    final errores = <String>[];

    for (final incidente in pendientes) {
      try {
        await _db.actualizarIncidente(
          incidente.idLocal,
          estadoSincronizacion: IncidenteLocal.estadoSyncSincronizando,
          ultimoError: null,
        );

        var idBackend = incidente.idBackend;
        if (idBackend == null || idBackend <= 0) {
          final respuesta = await _sincronizarIncidenteOffline(incidente);
          if (respuesta.estadoSync == IncidenteLocal.estadoSyncConflicto) {
            conflictos++;
            await _db.actualizarIncidente(
              incidente.idLocal,
              idBackend: respuesta.idBackend,
              idConflicto: respuesta.idConflicto,
              estadoSincronizacion: IncidenteLocal.estadoSyncConflicto,
              ultimoError: respuesta.error ?? 'Requiere revision.',
            );
            continue;
          }

          idBackend = respuesta.idBackend;
          if (idBackend == null || idBackend <= 0) {
            throw Exception('El backend no devolvio id_backend valido.');
          }
        }

        await _db.actualizarIncidente(
          incidente.idLocal,
          idBackend: idBackend,
          limpiarConflicto: true,
          estadoSincronizacion: IncidenteLocal.estadoSyncSincronizando,
          ultimoError: null,
        );

        final evidenciasConError = await _sincronizarEvidencias(
          incidente.idLocal,
          idBackend,
        );

        if (evidenciasConError > 0) {
          parciales++;
          await _db.actualizarIncidente(
            incidente.idLocal,
            idBackend: idBackend,
            estadoSincronizacion: IncidenteLocal.estadoSyncParcial,
            ultimoError:
                '$evidenciasConError evidencia(s) no pudieron sincronizarse.',
          );
        } else {
          sincronizados++;
          await _db.actualizarIncidente(
            incidente.idLocal,
            idBackend: idBackend,
            estadoSincronizacion: IncidenteLocal.estadoSyncSincronizado,
            ultimoError: null,
          );
        }
      } catch (e) {
        conError++;
        final error = e.toString().replaceFirst('Exception: ', '');
        errores.add('${incidente.idLocal}: $error');
        await _db.actualizarIncidente(
          incidente.idLocal,
          estadoSincronizacion: IncidenteLocal.estadoSyncError,
          ultimoError: error,
        );
      }
    }

    return OfflineSyncResult(
      total: pendientes.length,
      sincronizados: sincronizados,
      parciales: parciales,
      conflictos: conflictos,
      conError: conError,
      errores: errores,
    );
  }

  Future<_IncidenteSyncResponse> _sincronizarIncidenteOffline(
    IncidenteLocal incidente,
  ) async {
    // CU-OFF-09: POST /sync/incidentes usa id_local_origen para no duplicar.
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion vencida. Inicia sesion nuevamente.');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/sync/incidentes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(incidente.toSyncJson()),
    );

    final body = utf8.decode(response.bodyBytes);
    final data = body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(body));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data['detail']?.toString() ??
          data['error']?.toString() ??
          'No se pudo sincronizar el incidente.';
      throw Exception(detail);
    }

    final estadoSync = data['estado_sync']?.toString() ??
        IncidenteLocal.estadoSyncSincronizado;

    if (estadoSync == IncidenteLocal.estadoSyncConflicto) {
      // CU-OFF-14: Guardar id_conflicto y detener evidencias hasta arbitraje.
      final conflicto = data['conflicto'] is Map
          ? Map<String, dynamic>.from(data['conflicto'])
          : <String, dynamic>{};
      final idConflicto = int.tryParse(conflicto['id']?.toString() ?? '');
      final idBackend = int.tryParse(
        (conflicto['id_incidente_backend'] ?? data['id_backend'])?.toString() ??
            '',
      );
      return _IncidenteSyncResponse(
        estadoSync: IncidenteLocal.estadoSyncConflicto,
        idBackend: idBackend,
        idConflicto: idConflicto,
        error: 'Conflicto detectado: requiere revision.',
      );
    }

    final idBackend = data['id_backend'] ??
        data['codigo'] ??
        (data['incidente'] is Map ? data['incidente']['codigo'] : null);
    final parsed = int.tryParse(idBackend?.toString() ?? '');
    return _IncidenteSyncResponse(
      estadoSync: IncidenteLocal.estadoSyncSincronizado,
      idBackend: parsed,
    );
  }

  Future<int> _sincronizarEvidencias(
    String incidenteLocalId,
    int idBackend,
  ) async {
    // CU-OFF-10: Luego del id_backend se suben imagenes, audios y texto pendientes.
    final evidencias = await _db.listarEvidenciasPendientes(incidenteLocalId);
    var conError = 0;

    for (final evidencia in evidencias) {
      try {
        await _db.actualizarEvidencia(
          evidencia.idLocal,
          idBackend: idBackend,
          estadoSincronizacion: IncidenteLocal.estadoSyncSincronizando,
        );

        final resultado = await _subirEvidencia(evidencia, idBackend);
        if (resultado['ok'] != true) {
          throw Exception(resultado['error'] ?? 'No se pudo subir evidencia.');
        }

        await _db.actualizarEvidencia(
          evidencia.idLocal,
          idBackend: idBackend,
          estadoSincronizacion: IncidenteLocal.estadoSyncSincronizado,
          ultimoError: null,
        );
      } catch (e) {
        conError++;
        final error = e.toString().replaceFirst('Exception: ', '');
        await _db.actualizarEvidencia(
          evidencia.idLocal,
          idBackend: idBackend,
          estadoSincronizacion: IncidenteLocal.estadoSyncError,
          ultimoError: error,
        );
      }
    }

    return conError;
  }

  Future<List<SyncConflicto>> listarConflictosPendientes({
    String? codigoUsuario,
  }) async {
    // CU-OFF-15: GET /sync/conflictos para mostrar conflictos pendientes.
    final token = await _auth.getToken();
    final query = {
      'estado': 'PENDIENTE',
      if (codigoUsuario != null && codigoUsuario.isNotEmpty)
        'codigo_usuario': codigoUsuario,
    };
    final uri = Uri.parse('${AppConfig.baseUrl}/sync/conflictos').replace(
      queryParameters: query,
    );
    final response = await http.get(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron listar conflictos: $body');
    }

    final data = jsonDecode(body);
    if (data is! List) return [];
    return data
        .map((item) => SyncConflicto.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> resolverConflicto({
    required int idConflicto,
    required String accion,
    required String resueltoPor,
    required String observacion,
  }) async {
    // CU-OFF-16: POST /sync/resolver-conflicto/{id} con accion de arbitraje.
    final token = await _auth.getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/sync/resolver-conflicto/$idConflicto'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'accion': accion,
        'resuelto_por': resueltoPor,
        'observacion': observacion,
      }),
    );

    final body = utf8.decode(response.bodyBytes);
    final data = body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(body));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['detail']?.toString() ?? 'No se pudo resolver el conflicto.',
      );
    }

    await _aplicarResolucionLocal(idConflicto, accion, data);
    return {'ok': true, 'data': data};
  }

  Future<void> _aplicarResolucionLocal(
    int idConflicto,
    String accion,
    Map<String, dynamic> data,
  ) async {
    final incidente = await _db.obtenerIncidentePorConflicto(idConflicto);
    if (incidente == null) return;

    final idBackend = int.tryParse(
          (data['id_backend'] ??
                      data['id_incidente_backend'] ??
                      (data['incidente'] is Map
                          ? data['incidente']['codigo']
                          : null))
                  ?.toString() ??
              '',
        ) ??
        incidente.idBackend;

    if (accion == 'FUSIONAR_EVIDENCIAS' && idBackend != null) {
      final errores =
          await _sincronizarEvidencias(incidente.idLocal, idBackend);
      await _db.actualizarIncidente(
        incidente.idLocal,
        idBackend: idBackend,
        limpiarConflicto: true,
        estadoSincronizacion: errores == 0
            ? IncidenteLocal.estadoSyncSincronizado
            : IncidenteLocal.estadoSyncParcial,
        ultimoError: errores == 0
            ? null
            : '$errores evidencia(s) no pudieron sincronizarse.',
      );
      return;
    }

    if (accion == 'CREAR_NUEVO') {
      await _db.actualizarIncidente(
        incidente.idLocal,
        idBackend: idBackend,
        limpiarConflicto: true,
        estadoSincronizacion: idBackend == null
            ? IncidenteLocal.estadoSyncPendiente
            : IncidenteLocal.estadoSyncParcial,
        ultimoError: idBackend == null
            ? 'Conflicto resuelto. Reintenta la sincronizacion.'
            : null,
      );
      return;
    }

    if (accion == 'CONSERVAR_SERVIDOR' || accion == 'DESCARTAR_LOCAL') {
      await _db.actualizarEvidenciasPorIncidente(
        incidente.idLocal,
        idBackend: idBackend,
        estadoSincronizacion: IncidenteLocal.estadoSyncSincronizado,
      );
      await _db.actualizarIncidente(
        incidente.idLocal,
        idBackend: idBackend,
        limpiarConflicto: true,
        estadoSincronizacion: IncidenteLocal.estadoSyncSincronizado,
        ultimoError: null,
      );
    }
  }

  Future<Map<String, dynamic>> _subirEvidencia(
    EvidenciaLocal evidencia,
    int idBackend,
  ) async {
    switch (evidencia.tipoEvidencia) {
      case EvidenciaLocal.tipoImagen:
        final ruta = evidencia.rutaArchivoLocal;
        if (ruta == null || ruta.isEmpty || !File(ruta).existsSync()) {
          throw Exception('La imagen local no tiene ruta valida.');
        }
        return _evidenciaService.subirImagen(
          idIncidente: idBackend,
          imagen: File(ruta),
        );
      case EvidenciaLocal.tipoAudio:
        final ruta = evidencia.rutaArchivoLocal;
        if (ruta == null || ruta.isEmpty || !File(ruta).existsSync()) {
          throw Exception('El audio local no tiene ruta valida.');
        }
        return _evidenciaService.subirAudio(
          idIncidente: idBackend,
          audio: File(ruta),
        );
      case EvidenciaLocal.tipoTexto:
        final texto = evidencia.texto;
        if (texto == null || texto.trim().isEmpty) {
          return {'ok': true};
        }
        return _evidenciaService.subirTexto(
          idIncidente: idBackend,
          descripcion: texto,
        );
      default:
        throw Exception('Tipo de evidencia no soportado.');
    }
  }
}
