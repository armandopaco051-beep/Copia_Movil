class ChatIncidente {
  final int idIncidente;
  final int idChat;
  final bool chatActivo;
  final ParticipanteChat participante;
  final List<MensajeChat> mensajes;

  ChatIncidente({
    required this.idIncidente,
    required this.idChat,
    required this.chatActivo,
    required this.participante,
    required this.mensajes,
  });

  factory ChatIncidente.fromJson(Map<String, dynamic> json) {
    final mensajes = (json['mensajes'] as List? ?? [])
        .map((e) => MensajeChat.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    return ChatIncidente(
      idIncidente: _toInt(json['id_incidente']),
      idChat: _toInt(json['id_chat']),
      chatActivo: json['chat_activo'] == true,
      participante: ParticipanteChat.fromJson(
        Map<String, dynamic>.from(json['participante'] as Map? ?? {}),
      ),
      mensajes: mensajes,
    );
  }
}

class ParticipanteChat {
  final String id;
  final String tipo;
  final bool puedeEnviar;

  ParticipanteChat({
    required this.id,
    required this.tipo,
    required this.puedeEnviar,
  });

  factory ParticipanteChat.fromJson(Map<String, dynamic> json) {
    return ParticipanteChat(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      puedeEnviar: json['puede_enviar'] == true,
    );
  }
}

class MensajeChat {
  final int id;
  final int idChat;
  final int idIncidente;
  final String emisorId;
  final String emisorTipo;
  final String mensaje;
  final String tipoMensaje;
  final bool leido;
  final DateTime fechaHora;

  MensajeChat({
    required this.id,
    required this.idChat,
    required this.idIncidente,
    required this.emisorId,
    required this.emisorTipo,
    required this.mensaje,
    required this.tipoMensaje,
    required this.leido,
    required this.fechaHora,
  });

  factory MensajeChat.fromJson(Map<String, dynamic> json) {
    return MensajeChat(
      id: _toInt(json['id']),
      idChat: _toInt(json['id_chat']),
      idIncidente: _toInt(json['id_incidente']),
      emisorId: json['emisor_id']?.toString() ?? '',
      emisorTipo: json['emisor_tipo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      tipoMensaje: json['tipo_mensaje']?.toString() ?? 'texto',
      leido: json['leido'] == true,
      fechaHora: DateTime.tryParse(json['fecha_hora']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJsonEnvio() {
    return {
      'mensaje': mensaje,
      'tipo_mensaje': tipoMensaje,
    };
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
