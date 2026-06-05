class EtaTracking {
  final int idIncidente;
  final int idAsignacion;
  final String codigoTecnico;
  final String estado;
  final double distanciaKm;
  final int etaMinutos;
  final double velocidadPromedioKmh;
  final UbicacionTecnico ubicacionTecnico;
  final UbicacionCliente ubicacionCliente;
  final bool vigente;

  EtaTracking({
    required this.idIncidente,
    required this.idAsignacion,
    required this.codigoTecnico,
    required this.estado,
    required this.distanciaKm,
    required this.etaMinutos,
    required this.velocidadPromedioKmh,
    required this.ubicacionTecnico,
    required this.ubicacionCliente,
    required this.vigente,
  });

  factory EtaTracking.fromJson(Map<String, dynamic> json) {
    return EtaTracking(
      idIncidente: _toInt(json['id_incidente']),
      idAsignacion: _toInt(json['id_asignacion']),
      codigoTecnico: json['codigo_tecnico']?.toString() ?? '',
      estado: json['estado']?.toString() ?? 'Sin estado',
      distanciaKm: _toDouble(json['distancia_km']),
      etaMinutos: _toInt(json['eta_minutos']),
      velocidadPromedioKmh: _toDouble(json['velocidad_promedio_kmh']),
      ubicacionTecnico: UbicacionTecnico.fromJson(
        Map<String, dynamic>.from(json['ubicacion_tecnico'] as Map? ?? {}),
      ),
      ubicacionCliente: UbicacionCliente.fromJson(
        Map<String, dynamic>.from(json['ubicacion_cliente'] as Map? ?? {}),
      ),
      vigente: json['vigente'] == true,
    );
  }
}

class UbicacionTecnico {
  final double latitud;
  final double longitud;
  final DateTime? fecha;
  final int segundosDesdeActualizacion;

  UbicacionTecnico({
    required this.latitud,
    required this.longitud,
    this.fecha,
    required this.segundosDesdeActualizacion,
  });

  factory UbicacionTecnico.fromJson(Map<String, dynamic> json) {
    return UbicacionTecnico(
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? ''),
      segundosDesdeActualizacion:
          _toInt(json['segundos_desde_actualizacion']),
    );
  }
}

class UbicacionCliente {
  final double latitud;
  final double longitud;

  UbicacionCliente({
    required this.latitud,
    required this.longitud,
  });

  factory UbicacionCliente.fromJson(Map<String, dynamic> json) {
    return UbicacionCliente(
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
    );
  }
}

class UltimaUbicacionTecnico {
  final int idAsignacion;
  final int idIncidente;
  final String codigoTecnico;
  final double latitud;
  final double longitud;
  final String estado;
  final DateTime? fecha;

  UltimaUbicacionTecnico({
    required this.idAsignacion,
    required this.idIncidente,
    required this.codigoTecnico,
    required this.latitud,
    required this.longitud,
    required this.estado,
    this.fecha,
  });

  factory UltimaUbicacionTecnico.fromJson(Map<String, dynamic> json) {
    return UltimaUbicacionTecnico(
      idAsignacion: _toInt(json['id_asignacion']),
      idIncidente: _toInt(json['id_incidente']),
      codigoTecnico: json['codigo_tecnico']?.toString() ?? '',
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
      estado: json['estado']?.toString() ?? 'Sin estado',
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? ''),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
