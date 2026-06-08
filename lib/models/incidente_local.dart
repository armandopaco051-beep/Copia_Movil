class IncidenteLocal {
  static const estadoLocalRegistrado = 'REGISTRADO_LOCAL';
  static const estadoSyncPendiente = 'PENDIENTE';
  static const estadoSyncSincronizando = 'SINCRONIZANDO';
  static const estadoSyncSincronizado = 'SINCRONIZADO';
  static const estadoSyncError = 'ERROR';
  static const estadoSyncConflicto = 'CONFLICTO';
  static const estadoSyncParcial = 'SINCRONIZADO_PARCIAL';

  final String idLocal;
  final int? idBackend;
  final String clienteId;
  final int vehiculoId;
  final int categoriaId;
  final int prioridadId;
  final String descripcion;
  final double latitud;
  final double longitud;
  final String fechaCreacionLocal;
  final String fechaReporte;
  final String estadoLocal;
  final String estadoSincronizacion;
  final int versionLocal;
  final String? ultimoError;
  final int? idConflicto;
  final bool cotizacionExpress;

  const IncidenteLocal({
    required this.idLocal,
    this.idBackend,
    required this.clienteId,
    required this.vehiculoId,
    required this.categoriaId,
    required this.prioridadId,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.fechaCreacionLocal,
    required this.fechaReporte,
    required this.estadoLocal,
    required this.estadoSincronizacion,
    required this.versionLocal,
    this.ultimoError,
    this.idConflicto,
    required this.cotizacionExpress,
  });

  factory IncidenteLocal.fromMap(Map<String, Object?> map) {
    return IncidenteLocal(
      idLocal: map['id_local'].toString(),
      idBackend: map['id_backend'] == null
          ? null
          : int.tryParse(map['id_backend'].toString()),
      clienteId: map['cliente_id'].toString(),
      vehiculoId: int.parse(map['vehiculo_id'].toString()),
      categoriaId: int.parse(map['categoria_id'].toString()),
      prioridadId: int.parse(map['prioridad_id'].toString()),
      descripcion: map['descripcion'].toString(),
      latitud: double.parse(map['latitud'].toString()),
      longitud: double.parse(map['longitud'].toString()),
      fechaCreacionLocal: map['fecha_creacion_local'].toString(),
      fechaReporte:
          (map['fecha_reporte'] ?? map['fecha_creacion_local']).toString(),
      estadoLocal: map['estado_local'].toString(),
      estadoSincronizacion: map['estado_sincronizacion'].toString(),
      versionLocal: int.parse(map['version_local'].toString()),
      ultimoError: map['ultimo_error']?.toString(),
      idConflicto: map['id_conflicto'] == null
          ? null
          : int.tryParse(map['id_conflicto'].toString()),
      cotizacionExpress: map['cotizacion_express'] == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_local': idLocal,
      'id_backend': idBackend,
      'cliente_id': clienteId,
      'vehiculo_id': vehiculoId,
      'categoria_id': categoriaId,
      'prioridad_id': prioridadId,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_creacion_local': fechaCreacionLocal,
      'fecha_reporte': fechaReporte,
      'estado_local': estadoLocal,
      'estado_sincronizacion': estadoSincronizacion,
      'version_local': versionLocal,
      'ultimo_error': ultimoError,
      'id_conflicto': idConflicto,
      'cotizacion_express': cotizacionExpress ? 1 : 0,
    };
  }

  Map<String, Object?> toSyncJson() {
    return {
      'id_local_origen': idLocal,
      'origen_registro': 'OFFLINE',
      'fecha_creacion_local': fechaCreacionLocal,
      'version_local': versionLocal,
      'estado_local_origen': estadoLocal,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_reporte': fechaReporte,
      'id_prioridad': prioridadId,
      'id_categoria_problema': categoriaId,
      'id_estado_incidente': 1,
      'id_vehiculo': vehiculoId,
      'codigo_usuario': clienteId,
      'cotizacion_express': cotizacionExpress,
    };
  }
}
