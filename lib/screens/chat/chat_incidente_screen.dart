import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/chat.dart';
import '../../services/chat_service.dart';

class ChatIncidenteScreen extends StatefulWidget {
  final int idIncidente;

  const ChatIncidenteScreen({super.key, required this.idIncidente});

  @override
  State<ChatIncidenteScreen> createState() => _ChatIncidenteScreenState();
}

class _ChatIncidenteScreenState extends State<ChatIncidenteScreen> {
  final _service = ChatService();
  final _mensajeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  ChatIncidente? _chat;
  List<MensajeChat> _mensajes = [];
  bool _cargando = true;
  bool _conectado = false;
  bool _conectando = false;
  bool _enviando = false;
  String? _error;
  int _intentosReconexion = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final chat = await _service.cargarHistorial(widget.idIncidente);
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _mensajes = chat.mensajes;
        _cargando = false;
      });
      _moverAlFinal();
      await _conectarWebSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _conectarWebSocket() async {
    if (_conectando) return;
    setState(() {
      _conectando = true;
      _error = null;
    });

    try {
      await _subscription?.cancel();
      await _channel?.sink.close();

      final channel = await _service.conectarWebSocket(widget.idIncidente);
      _channel = channel;
      _subscription = channel.stream.listen(
        _procesarMensajeEntrante,
        onDone: _manejarDesconexion,
        onError: (_) => _manejarDesconexion(),
        cancelOnError: true,
      );

      if (!mounted) return;
      setState(() {
        _conectado = true;
        _conectando = false;
        _intentosReconexion = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conectado = false;
        _conectando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _programarReconexion();
    }
  }

  void _procesarMensajeEntrante(dynamic event) {
    try {
      final data = event is String ? jsonDecode(event) : event;
      if (data is! Map) return;
      final mensaje = MensajeChat.fromJson(Map<String, dynamic>.from(data));

      if (!mounted || _yaExiste(mensaje)) return;
      setState(() {
        _mensajes.removeWhere(
          (m) =>
              m.id < 0 &&
              mensaje.emisorTipo.toLowerCase() == 'cliente' &&
              m.mensaje == mensaje.mensaje,
        );
        _mensajes.add(mensaje);
      });
      _moverAlFinal();
    } catch (_) {}
  }

  void _manejarDesconexion() {
    if (!mounted) return;
    setState(() {
      _conectado = false;
      _conectando = false;
    });
    _programarReconexion();
  }

  void _programarReconexion() {
    _reconnectTimer?.cancel();
    _intentosReconexion++;
    final segundos = (_intentosReconexion * 2).clamp(2, 15).toInt();
    _reconnectTimer = Timer(
      Duration(seconds: segundos),
      () {
        if (mounted) _conectarWebSocket();
      },
    );
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty || !_puedeEnviar || !_conectado || _channel == null) {
      return;
    }

    setState(() => _enviando = true);
    try {
      _channel!.sink.add(_service.encodeMensaje(texto));
      _mensajeCtrl.clear();
      _agregarMensajeLocal(texto);
    } catch (e) {
      setState(() {
        _error = 'No se pudo enviar el mensaje';
        _conectado = false;
      });
      _programarReconexion();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _agregarMensajeLocal(String texto) {
    final chat = _chat;
    final participante = chat?.participante;
    final mensaje = MensajeChat(
      id: -DateTime.now().millisecondsSinceEpoch,
      idChat: chat?.idChat ?? 0,
      idIncidente: widget.idIncidente,
      emisorId: participante?.id ?? '',
      emisorTipo: 'cliente',
      mensaje: texto,
      tipoMensaje: 'texto',
      leido: false,
      fechaHora: DateTime.now(),
    );
    setState(() => _mensajes.add(mensaje));
    _moverAlFinal();
  }

  bool _yaExiste(MensajeChat mensaje) {
    if (mensaje.id <= 0) return false;
    return _mensajes.any((m) => m.id == mensaje.id);
  }

  bool get _puedeEnviar {
    return _chat?.chatActivo == true && _chat?.participante.puedeEnviar == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat con tecnico',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Reconectar',
            icon: const Icon(Icons.sync),
            onPressed: _conectando ? null : _conectarWebSocket,
          ),
        ],
      ),
      body: Column(children: [
        _estadoConexion(),
        Expanded(child: _contenido()),
        _inputMensaje(),
      ]),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }

    if (_error != null && _mensajes.isEmpty) {
      return _estadoError(_error!);
    }

    if (_mensajes.isEmpty) {
      return _estadoVacio();
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _mensajes.length,
      itemBuilder: (_, i) => _burbuja(_mensajes[i]),
    );
  }

  Widget _estadoConexion() {
    final color = _conectado
        ? const Color(0xFF1D9E75)
        : _conectando
            ? const Color(0xFFFF6B35)
            : Colors.redAccent;
    final texto = _conectado
        ? 'Conectado'
        : _conectando
            ? 'Reconectando...'
            : 'Sin conexion';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: const Color(0xFF161B22),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(texto, style: TextStyle(color: color, fontSize: 12)),
        const Spacer(),
        if (_chat != null)
          Text(
            'Incidente #${_chat!.idIncidente}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
      ]),
    );
  }

  Widget _burbuja(MensajeChat mensaje) {
    final esCliente = mensaje.emisorTipo.toLowerCase() == 'cliente';
    final color = esCliente ? const Color(0xFFFF6B35) : const Color(0xFF161B22);
    final align = esCliente ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(esCliente ? 16 : 4),
      bottomRight: Radius.circular(esCliente ? 4 : 16),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: esCliente
                ? null
                : Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment:
                esCliente ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                mensaje.mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text(
                _formatearHora(mensaje.fechaHora),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputMensaje() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _mensajeCtrl,
              enabled: _puedeEnviar && _conectado,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviarMensaje(),
              decoration: InputDecoration(
                hintText: _puedeEnviar
                    ? 'Escribe un mensaje...'
                    : 'Chat no disponible',
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  _enviando || !_puedeEnviar || !_conectado ? null : _enviarMensaje,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _estadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.chat_bubble_outline,
              color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar el chat',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            style: TextStyle(color: Colors.grey[500], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _inicializar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.forum_outlined, color: Colors.grey[600], size: 58),
          const SizedBox(height: 16),
          Text(
            'Sin mensajes todavia',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando el tecnico escriba, sus mensajes apareceran aqui.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  void _moverAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatearHora(DateTime fecha) {
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }
}
