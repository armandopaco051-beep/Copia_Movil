class NotificacionCliente {
  final int codigo;
  final DateTime fechaEnvio;
  final String mensaje;
  final bool leido;
  final String idUsuario;
  final int? idIncidente;

  NotificacionCliente({
    required this.codigo,
    required this.fechaEnvio,
    required this.mensaje,
    required this.leido,
    required this.idUsuario,
    required this.idIncidente,
  });

  factory NotificacionCliente.fromJson(Map<String, dynamic> json) {
    return NotificacionCliente(
      codigo: _toInt(json['codigo']),
      fechaEnvio:
          DateTime.tryParse(json['fecha_envio']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      mensaje: json['mensaje']?.toString() ?? '',
      leido: json['leido'] == true || json['leido'] == 1,
      idUsuario: json['id_usuario']?.toString() ?? '',
      idIncidente: json['id_incidente'] == null
          ? null
          : _toInt(json['id_incidente']),
    );
  }

  NotificacionCliente copyWith({bool? leido}) {
    return NotificacionCliente(
      codigo: codigo,
      fechaEnvio: fechaEnvio,
      mensaje: mensaje,
      leido: leido ?? this.leido,
      idUsuario: idUsuario,
      idIncidente: idIncidente,
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
