class SyncConflicto {
  final int id;
  final String idLocalOrigen;
  final String codigoUsuario;
  final int? idIncidenteBackend;
  final String tipoConflicto;
  final String estado;
  final String reglaArbitraje;
  final Map<String, dynamic> datosLocales;
  final Map<String, dynamic> datosServidor;
  final String? resolucion;
  final String? observacion;
  final String? resueltoPor;
  final String? fechaDeteccion;
  final String? fechaResolucion;

  const SyncConflicto({
    required this.id,
    required this.idLocalOrigen,
    required this.codigoUsuario,
    this.idIncidenteBackend,
    required this.tipoConflicto,
    required this.estado,
    required this.reglaArbitraje,
    required this.datosLocales,
    required this.datosServidor,
    this.resolucion,
    this.observacion,
    this.resueltoPor,
    this.fechaDeteccion,
    this.fechaResolucion,
  });

  factory SyncConflicto.fromJson(Map<String, dynamic> json) {
    return SyncConflicto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      idLocalOrigen: json['id_local_origen']?.toString() ?? '',
      codigoUsuario: json['codigo_usuario']?.toString() ?? '',
      idIncidenteBackend:
          int.tryParse(json['id_incidente_backend']?.toString() ?? ''),
      tipoConflicto: json['tipo_conflicto']?.toString() ?? 'CONFLICTO',
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      reglaArbitraje: json['regla_arbitraje']?.toString() ?? '',
      datosLocales: Map<String, dynamic>.from(json['datos_locales'] ?? {}),
      datosServidor: Map<String, dynamic>.from(json['datos_servidor'] ?? {}),
      resolucion: json['resolucion']?.toString(),
      observacion: json['observacion']?.toString(),
      resueltoPor: json['resuelto_por']?.toString(),
      fechaDeteccion: json['fecha_deteccion']?.toString(),
      fechaResolucion: json['fecha_resolucion']?.toString(),
    );
  }
}
