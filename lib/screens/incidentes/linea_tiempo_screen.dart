import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/linea_tiempo.dart';
import '../../services/incidente_service.dart';
import '../chat/chat_incidente_screen.dart';
import '../evaluaciones/evaluar_servicio_screen.dart';
import '../pagos/pago_servicio_screen.dart';
import '../tracking/tracking_en_vivo_screen.dart';
import '../validacion/codigo_arribo_screen.dart';

class LineaTiempoScreen extends StatefulWidget {
  final int idIncidente;

  const LineaTiempoScreen({super.key, required this.idIncidente});

  @override
  State<LineaTiempoScreen> createState() => _LineaTiempoScreenState();
}

class _LineaTiempoScreenState extends State<LineaTiempoScreen> {
  late Future<LineaTiempoServicio> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = IncidenteService().consultarLineaTiempo(widget.idIncidente);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Linea de tiempo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Evaluar',
            icon: const Icon(Icons.star_rate_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EvaluarServicioScreen(
                    idIncidente: widget.idIncidente,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Pago',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PagoServicioScreen(
                    idIncidente: widget.idIncidente,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatIncidenteScreen(
                    idIncidente: widget.idIncidente,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'PIN o QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CodigoArriboScreen(
                    idIncidente: widget.idIncidente,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ubicacion en vivo',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingEnVivoScreen(
                    idIncidente: widget.idIncidente,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<LineaTiempoServicio>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            );
          }

          if (snapshot.hasError) {
            return _estadoError(snapshot.error.toString());
          }

          final lineaTiempo = snapshot.data;
          if (lineaTiempo == null || lineaTiempo.eventos.isEmpty) {
            return _estadoVacio();
          }

          return RefreshIndicator(
            color: const Color(0xFFFF6B35),
            onRefresh: _refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _resumen(lineaTiempo),
                if (_servicioFinalizado(lineaTiempo)) ...[
                  const SizedBox(height: 16),
                  _evaluacionCard(),
                ],
                const SizedBox(height: 20),
                Text(
                  'Avance del servicio',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  lineaTiempo.eventos.length,
                  (i) => _eventoItem(
                    lineaTiempo.eventos[i],
                    i == lineaTiempo.eventos.length - 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _resumen(LineaTiempoServicio lineaTiempo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incidente #${lineaTiempo.idIncidente}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lineaTiempo.estadoActual,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          _estadoChip(lineaTiempo.estadoActual),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _datoResumen('Eventos', lineaTiempo.totalEventos.toString()),
          const SizedBox(width: 12),
          _datoResumen('Estado ID', lineaTiempo.idEstadoActual.toString()),
        ]),
      ]),
    );
  }

  Widget _datoResumen(String label, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ]),
      ),
    );
  }

  Widget _evaluacionCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EvaluarServicioScreen(
              idIncidente: widget.idIncidente,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB020).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star_rate_outlined,
              color: Color(0xFFFFB020),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evaluar servicio',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Califica el servicio finalizado',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[500]),
        ]),
      ),
    );
  }

  Widget _eventoItem(EventoLineaTiempo evento, bool ultimo) {
    final color = _colorEstado(evento.estado);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                _iconoEvento(evento.codigo),
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!ultimo)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.only(top: 6),
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(
                      evento.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _estadoChip(evento.estado),
                ]),
                const SizedBox(height: 6),
                Text(
                  _formatearFecha(evento.fecha),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (evento.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    evento.descripcion,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (evento.datos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: evento.datos.entries
                        .map((entry) => _datoChip(entry.key, entry.value))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _datoChip(String clave, dynamic valor) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 98,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          '${_formatearClave(clave)}: $valor',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final color = _colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Text(
          estado,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _estadoError(String mensaje) {
    final limpio = mensaje.replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 54),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la linea de tiempo',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            limpio,
            style: TextStyle(color: Colors.grey[500], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(_cargar),
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
          Icon(Icons.timeline_outlined, color: Colors.grey[600], size: 58),
          const SizedBox(height: 16),
          Text(
            'Sin eventos registrados',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Este incidente aun no tiene historial de estados disponible.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Color _colorEstado(String estado) {
    final valor = estado.toLowerCase();
    if (valor.contains('complet')) return const Color(0xFF4CAF50);
    if (valor.contains('proceso') || valor.contains('camino')) {
      return const Color(0xFFFF6B35);
    }
    if (valor.contains('cancel') || valor.contains('error')) {
      return const Color(0xFFF44336);
    }
    return const Color(0xFF8B949E);
  }

  bool _servicioFinalizado(LineaTiempoServicio lineaTiempo) {
    final estado = lineaTiempo.estadoActual.toLowerCase();
    if (estado.contains('final') || estado.contains('cerr')) return true;
    return lineaTiempo.eventos.any((evento) {
      final codigo = evento.codigo.toLowerCase();
      return codigo.contains('final') || codigo.contains('cierre');
    });
  }

  IconData _iconoEvento(String codigo) {
    final valor = codigo.toLowerCase();
    if (valor.contains('solicitud')) return Icons.assignment_turned_in_outlined;
    if (valor.contains('taller')) return Icons.home_repair_service_outlined;
    if (valor.contains('tecnico')) return Icons.engineering_outlined;
    if (valor.contains('desplaz') || valor.contains('camino')) {
      return Icons.local_shipping_outlined;
    }
    if (valor.contains('llegada')) return Icons.location_on_outlined;
    if (valor.contains('inicio')) return Icons.build_outlined;
    if (valor.contains('final')) return Icons.check_circle_outline;
    if (valor.contains('pago')) return Icons.payments_outlined;
    return Icons.radio_button_checked;
  }

  String _formatearFecha(DateTime fecha) {
    if (fecha.millisecondsSinceEpoch == 0) return 'Fecha no disponible';
    final dia = _dosDigitos(fecha.day);
    final mes = _dosDigitos(fecha.month);
    final hora = _dosDigitos(fecha.hour);
    final minuto = _dosDigitos(fecha.minute);
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }

  String _dosDigitos(int value) => value.toString().padLeft(2, '0');

  String _formatearClave(String clave) {
    return clave.replaceAll('_', ' ');
  }
}
