class EvidenciaLocal {
  static const tipoImagen = 'imagen';
  static const tipoAudio = 'audio';
  static const tipoTexto = 'texto';

  final String idLocal;
  final String incidenteLocalId;
  final int? idBackend;
  final String tipoEvidencia;
  final String? rutaArchivoLocal;
  final String? texto;
  final String estadoSincronizacion;
  final String? ultimoError;

  const EvidenciaLocal({
    required this.idLocal,
    required this.incidenteLocalId,
    this.idBackend,
    required this.tipoEvidencia,
    this.rutaArchivoLocal,
    this.texto,
    required this.estadoSincronizacion,
    this.ultimoError,
  });

  factory EvidenciaLocal.fromMap(Map<String, Object?> map) {
    return EvidenciaLocal(
      idLocal: map['id_local'].toString(),
      incidenteLocalId: map['incidente_local_id'].toString(),
      idBackend: map['id_backend'] == null
          ? null
          : int.tryParse(map['id_backend'].toString()),
      tipoEvidencia: map['tipo_evidencia'].toString(),
      rutaArchivoLocal: map['ruta_archivo_local']?.toString(),
      texto: (map['texto'] ?? map['contenido_texto'])?.toString(),
      estadoSincronizacion: map['estado_sincronizacion'].toString(),
      ultimoError: map['ultimo_error']?.toString(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_local': idLocal,
      'incidente_local_id': incidenteLocalId,
      'id_backend': idBackend,
      'tipo_evidencia': tipoEvidencia,
      'ruta_archivo_local': rutaArchivoLocal,
      'texto': texto,
      'estado_sincronizacion': estadoSincronizacion,
      'ultimo_error': ultimoError,
    };
  }
}
