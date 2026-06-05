class ValidacionArribo {
  final int idValidacion;
  final int idIncidente;
  final int idAsignacion;
  final String pin;
  final String qrToken;
  final DateTime? fechaGeneracion;
  final DateTime? fechaExpiracion;
  final int vigenciaMinutos;
  final bool usado;

  ValidacionArribo({
    required this.idValidacion,
    required this.idIncidente,
    required this.idAsignacion,
    required this.pin,
    required this.qrToken,
    this.fechaGeneracion,
    this.fechaExpiracion,
    required this.vigenciaMinutos,
    required this.usado,
  });

  factory ValidacionArribo.fromJson(Map<String, dynamic> json) {
    return ValidacionArribo(
      idValidacion: _toInt(json['id_validacion']),
      idIncidente: _toInt(json['id_incidente']),
      idAsignacion: _toInt(json['id_asignacion']),
      pin: json['pin']?.toString() ?? '',
      qrToken: json['qr_token']?.toString() ?? '',
      fechaGeneracion:
          DateTime.tryParse(json['fecha_generacion']?.toString() ?? ''),
      fechaExpiracion:
          DateTime.tryParse(json['fecha_expiracion']?.toString() ?? ''),
      vigenciaMinutos: _toInt(json['vigencia_minutos']),
      usado: json['usado'] == true,
    );
  }

  bool get vencido {
    if (fechaExpiracion == null) return false;
    return DateTime.now().isAfter(fechaExpiracion!);
  }

  int get minutosRestantes {
    if (fechaExpiracion == null) return 0;
    final diferencia = fechaExpiracion!.difference(DateTime.now()).inMinutes;
    return diferencia < 0 ? 0 : diferencia;
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
