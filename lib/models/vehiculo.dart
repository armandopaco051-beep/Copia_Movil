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
      codigo: int.tryParse((json['codigo'] ?? 0).toString()) ?? 0,
      modelo: (json['modelo'] ?? '').toString(),
      placa: (json['placa'] ?? '').toString(),
      marca: (json['marca'] ?? '').toString(),
      anio: (json['año'] ?? json['anio'] ?? '').toString(),
      activo: json['activo'] == true || json['activo'] == 1,
      idUsuario: (json['id_usuario'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'modelo': modelo,
        'placa': placa,
        'marca': marca,
        'anio': anio,
      };
}
