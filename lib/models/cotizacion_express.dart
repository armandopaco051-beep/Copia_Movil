class SolicitudCotizacion {
  final int id;
  final int idIncidente;
  final int ronda;
  final String estado;
  final DateTime? fechaVencimiento;
  final List<OfertaCotizacion> ofertas;

  SolicitudCotizacion({
    required this.id,
    required this.idIncidente,
    required this.ronda,
    required this.estado,
    required this.fechaVencimiento,
    required this.ofertas,
  });

  factory SolicitudCotizacion.fromJson(Map<String, dynamic> json) {
    final ofertas = (json['ofertas'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OfertaCotizacion.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();

    return SolicitudCotizacion(
      id: _toInt(json['id']),
      idIncidente: _toInt(json['id_incidente']),
      ronda: _toInt(json['ronda'], fallback: 1),
      estado: json['estado']?.toString().toUpperCase() ?? 'ABIERTA',
      fechaVencimiento:
          DateTime.tryParse(json['fecha_vencimiento']?.toString() ?? ''),
      ofertas: ofertas,
    );
  }

  bool get estaAbierta => estado == 'ABIERTA';
  bool get tieneRespuestas => estado == 'CON_RESPUESTAS';
  bool get estaFinalizada => estado == 'FINALIZADA';
  bool get estaVencida => estado == 'VENCIDA';
}

class OfertaCotizacion {
  final int id;
  final int idTaller;
  final TallerCotizacion taller;
  final String estado;
  final double distanciaKm;
  final double montoEstimado;
  final int tiempoLlegadaMinutos;
  final int tiempoReparacionMinutos;
  final String descripcionServicio;

  OfertaCotizacion({
    required this.id,
    required this.idTaller,
    required this.taller,
    required this.estado,
    required this.distanciaKm,
    required this.montoEstimado,
    required this.tiempoLlegadaMinutos,
    required this.tiempoReparacionMinutos,
    required this.descripcionServicio,
  });

  factory OfertaCotizacion.fromJson(Map<String, dynamic> json) {
    return OfertaCotizacion(
      id: _toInt(json['id']),
      idTaller: _toInt(json['id_taller']),
      taller: TallerCotizacion.fromJson(
        Map<String, dynamic>.from(json['taller'] as Map? ?? {}),
      ),
      estado: json['estado']?.toString().toUpperCase() ?? 'ENVIADA',
      distanciaKm: _toDouble(json['distancia_km']),
      montoEstimado: _toDouble(json['monto_estimado']),
      tiempoLlegadaMinutos: _toInt(json['tiempo_llegada_minutos']),
      tiempoReparacionMinutos:
          _toInt(json['tiempo_reparacion_minutos']),
      descripcionServicio:
          json['descripcion_servicio']?.toString() ?? 'Sin descripcion',
    );
  }

  bool get fueAceptada =>
      estado.contains('ACEPT') ||
      estado.contains('GANAD') ||
      estado.contains('SELECCION');
}

class TallerCotizacion {
  final String nombre;
  final String telefono;
  final String direccion;

  TallerCotizacion({
    required this.nombre,
    required this.telefono,
    required this.direccion,
  });

  factory TallerCotizacion.fromJson(Map<String, dynamic> json) {
    return TallerCotizacion(
      nombre: json['nombre']?.toString() ?? 'Taller',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
    );
  }
}

class AceptacionCotizacion {
  final String mensaje;
  final int idSolicitud;
  final int idCotizacion;
  final int idAsignacion;
  final int idIncidente;
  final int idTaller;
  final int idEstadoAsignacion;

  AceptacionCotizacion({
    required this.mensaje,
    required this.idSolicitud,
    required this.idCotizacion,
    required this.idAsignacion,
    required this.idIncidente,
    required this.idTaller,
    required this.idEstadoAsignacion,
  });

  factory AceptacionCotizacion.fromJson(Map<String, dynamic> json) {
    return AceptacionCotizacion(
      mensaje: json['mensaje']?.toString() ??
          'Cotizacion aceptada y taller asignado',
      idSolicitud: _toInt(json['id_solicitud']),
      idCotizacion: _toInt(json['id_cotizacion']),
      idAsignacion: _toInt(json['id_asignacion']),
      idIncidente: _toInt(json['id_incidente']),
      idTaller: _toInt(json['id_taller']),
      idEstadoAsignacion: _toInt(json['id_estado_asignacion']),
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
