class LineaTiempoServicio {
  final int idIncidente;
  final String estadoActual;
  final int idEstadoActual;
  final int totalEventos;
  final List<EventoLineaTiempo> eventos;

  LineaTiempoServicio({
    required this.idIncidente,
    required this.estadoActual,
    required this.idEstadoActual,
    required this.totalEventos,
    required this.eventos,
  });

  factory LineaTiempoServicio.fromJson(Map<String, dynamic> json) {
    final eventos = (json['eventos'] as List? ?? [])
        .map((e) => EventoLineaTiempo.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return LineaTiempoServicio(
      idIncidente: _toInt(json['id_incidente']),
      estadoActual: json['estado_actual']?.toString() ?? 'Sin estado',
      idEstadoActual: _toInt(json['id_estado_actual']),
      totalEventos: _toInt(json['total_eventos'], fallback: eventos.length),
      eventos: eventos,
    );
  }
}

class EventoLineaTiempo {
  final String codigo;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final String estado;
  final Map<String, dynamic> datos;

  EventoLineaTiempo({
    required this.codigo,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.estado,
    required this.datos,
  });

  factory EventoLineaTiempo.fromJson(Map<String, dynamic> json) {
    return EventoLineaTiempo(
      codigo: json['codigo']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? 'Evento',
      descripcion: json['descripcion']?.toString() ?? '',
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      estado: json['estado']?.toString() ?? 'pendiente',
      datos: Map<String, dynamic>.from(json['datos'] as Map? ?? {}),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
