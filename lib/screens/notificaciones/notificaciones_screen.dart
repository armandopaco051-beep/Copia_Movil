import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notificacion.dart';
import '../../services/notificacion_service.dart';
import '../incidentes/linea_tiempo_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _service = NotificacionService();
  List<NotificacionCliente> _notificaciones = [];
  bool _cargando = true;
  bool _soloNoLeidas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await _service.listar(
        soloNoLeidas: _soloNoLeidas,
        limit: _soloNoLeidas ? 20 : null,
      );
      if (!mounted) return;
      setState(() {
        _notificaciones = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _marcarTodas() async {
    try {
      await _service.marcarTodasComoLeidas();
      if (!mounted) return;
      if (_soloNoLeidas) {
        setState(() => _notificaciones = []);
      } else {
        setState(() {
          _notificaciones =
              _notificaciones.map((n) => n.copyWith(leido: true)).toList();
        });
      }
    } catch (e) {
      _mostrarError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _abrirNotificacion(NotificacionCliente notificacion) async {
    if (!notificacion.leido) {
      try {
        await _service.marcarComoLeida(notificacion.codigo);
        if (!mounted) return;
        setState(() {
          _notificaciones = _soloNoLeidas
              ? _notificaciones
                  .where((n) => n.codigo != notificacion.codigo)
                  .toList()
              : _notificaciones
                  .map((n) => n.codigo == notificacion.codigo
                      ? n.copyWith(leido: true)
                      : n)
                  .toList();
        });
      } catch (e) {
        _mostrarError(e.toString().replaceFirst('Exception: ', ''));
        return;
      }
    }

    final idIncidente = notificacion.idIncidente;
    if (idIncidente == null || idIncidente <= 0 || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineaTiempoScreen(idIncidente: idIncidente),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _soloNoLeidas ? 'Ver todas' : 'Solo no leidas',
            icon: Icon(_soloNoLeidas
                ? Icons.notifications_outlined
                : Icons.mark_email_unread_outlined),
            onPressed: () {
              setState(() => _soloNoLeidas = !_soloNoLeidas);
              _cargar();
            },
          ),
          IconButton(
            tooltip: 'Marcar todas como leidas',
            icon: const Icon(Icons.done_all),
            onPressed: _notificaciones.any((n) => !n.leido)
                ? _marcarTodas
                : null,
          ),
        ],
      ),
      body: _contenido(),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }

    if (_error != null) {
      return _estadoError(_error!);
    }

    if (_notificaciones.isEmpty) {
      return _estadoVacio();
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: _cargar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _notificaciones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _item(_notificaciones[i]),
      ),
    );
  }

  Widget _item(NotificacionCliente notificacion) {
    final color = notificacion.leido
        ? const Color(0xFF161B22)
        : const Color(0xFFFF6B35).withOpacity(0.13);

    return InkWell(
      onTap: () => _abrirNotificacion(notificacion),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notificacion.leido
                ? Colors.white.withOpacity(0.07)
                : const Color(0xFFFF6B35).withOpacity(0.45),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: notificacion.leido
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFFF6B35).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              notificacion.leido
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              color: notificacion.leido
                  ? Colors.grey[400]
                  : const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                notificacion.mensaje,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: notificacion.leido
                      ? FontWeight.normal
                      : FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _chip(
                  notificacion.leido ? 'Leida' : 'No leida',
                  notificacion.leido
                      ? const Color(0xFF8B949E)
                      : const Color(0xFFFF6B35),
                ),
                if (notificacion.idIncidente != null)
                  _chip(
                    'Incidente #${notificacion.idIncidente}',
                    const Color(0xFF1D9E75),
                  ),
                _chip(_formatearFecha(notificacion.fechaEnvio),
                    const Color(0xFF8B949E)),
              ]),
            ]),
          ),
          if (notificacion.idIncidente != null)
            Icon(Icons.chevron_right, color: Colors.grey[500]),
        ]),
      ),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _estadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.notifications_off_outlined,
              color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text(
            'No se pudieron cargar',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
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
          Icon(Icons.notifications_none, color: Colors.grey[600], size: 58),
          const SizedBox(height: 16),
          Text(
            _soloNoLeidas
                ? 'Sin notificaciones pendientes'
                : 'Sin notificaciones',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Las alertas de tus servicios apareceran aqui.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    if (fecha.millisecondsSinceEpoch == 0) return 'Fecha no disponible';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}
