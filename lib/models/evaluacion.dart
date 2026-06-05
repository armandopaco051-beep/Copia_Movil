class EvaluacionServicio {
  final int id;
  final int idIncidente;
  final int idAsignacion;
  final String codigoCliente;
  final String codigoTecnico;
  final int idTaller;
  final int calificacion;
  final int? puntualidad;
  final int? trato;
  final int? solucion;
  final int? precio;
  final String comentario;
  final DateTime? fechaEvaluacion;

  EvaluacionServicio({
    required this.id,
    required this.idIncidente,
    required this.idAsignacion,
    required this.codigoCliente,
    required this.codigoTecnico,
    required this.idTaller,
    required this.calificacion,
    this.puntualidad,
    this.trato,
    this.solucion,
    this.precio,
    required this.comentario,
    this.fechaEvaluacion,
  });

  factory EvaluacionServicio.fromJson(Map<String, dynamic> json) {
    return EvaluacionServicio(
      id: _toInt(json['id']),
      idIncidente: _toInt(json['id_incidente']),
      idAsignacion: _toInt(json['id_asignacion']),
      codigoCliente: json['codigo_cliente']?.toString() ?? '',
      codigoTecnico: json['codigo_tecnico']?.toString() ?? '',
      idTaller: _toInt(json['id_taller']),
      calificacion: _toInt(json['calificacion']),
      puntualidad: _toNullableInt(json['puntualidad']),
      trato: _toNullableInt(json['trato']),
      solucion: _toNullableInt(json['solucion']),
      precio: _toNullableInt(json['precio']),
      comentario: json['comentario']?.toString() ?? '',
      fechaEvaluacion:
          DateTime.tryParse(json['fecha_evaluacion']?.toString() ?? ''),
    );
  }
}

class EvaluacionRegistrada {
  final String mensaje;
  final EvaluacionServicio evaluacion;

  EvaluacionRegistrada({
    required this.mensaje,
    required this.evaluacion,
  });

  factory EvaluacionRegistrada.fromJson(Map<String, dynamic> json) {
    return EvaluacionRegistrada(
      mensaje: json['mensaje']?.toString() ?? 'Evaluacion registrada',
      evaluacion: EvaluacionServicio.fromJson(
        Map<String, dynamic>.from(json['evaluacion'] as Map? ?? {}),
      ),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
