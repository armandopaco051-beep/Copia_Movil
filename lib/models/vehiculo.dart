class Vehiculo {
  final int codigo;
  final String modelo;
  final String placa;
  final String marca;
  final String anio;
  final bool activo;
  // ✅ CAMBIO: de int a String
  final String idUsuario;

  Vehiculo({
    required this.codigo,
    required this.modelo,
    required this.placa,
    required this.marca,
    required this.anio,
    required this.activo,
    required this.idUsuario,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      codigo: json['codigo'],
      modelo: json['modelo'],
      placa: json['placa'],
      marca: json['marca'],
      anio: json['año'],
      activo: json['activo'],
      // ✅ CAMBIO: toString()
      idUsuario: json['id_usuario'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'modelo': modelo,
        'placa': placa,
        'marca': marca,
        'año': anio,
        'id_usuario': idUsuario,
      };
}
