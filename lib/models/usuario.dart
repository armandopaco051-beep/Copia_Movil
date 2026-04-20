class Usuario {
  // ✅ CAMBIO: de int a String
  final String codigo;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final bool estado;
  final String password;
  final int idRol;

  Usuario({
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.password,
    required this.telefono,
    required this.estado,
    required this.idRol,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      // ✅ CAMBIO: toString() por si viene como número igual
      codigo: json['codigo'].toString(),
      nombre: json['nombre'],
      apellido: json['apellido'],
      email: json['email'],
      password: json['password'],
      telefono: json['telefono'],
      estado: json['estado'],
      idRol: json['id_rol'],
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'telefono': telefono,
        'password': password,
        'id_rol': idRol,
      };
}
