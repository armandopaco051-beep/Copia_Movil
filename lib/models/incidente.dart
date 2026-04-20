class Incidente {
  final int codigo;
  final String descripcion;
  final double latitud;
  final double longitud;
  final String fechaReporte;
  final String? fechaCierre;
  final int idPrioridad;
  final int idCategoriaProblema;
  final int idEstadoIncidente;
  final int idVehiculo;
  final String codigoUsuario;

  Incidente({
    required this.codigo,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.fechaReporte,
    this.fechaCierre,
    required this.idPrioridad,
    required this.idCategoriaProblema,
    required this.idEstadoIncidente,
    required this.idVehiculo,
    required this.codigoUsuario,
  });

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      codigo: json['codigo'],
      descripcion: json['descripcion'],
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
      fechaReporte: json['fecha_reporte'],
      fechaCierre: json['fecha_cierre'],
      idPrioridad: json['id_prioridad'],
      idCategoriaProblema: json['id_categoria_problema'],
      idEstadoIncidente: json['id_estado_incidente'],
      idVehiculo: json['id_vehiculo'],
      codigoUsuario: json['codigo_usuario'],
    );
  }
}
