import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/cotizacion_express.dart';
import '../../services/cotizacion_express_service.dart';
import '../tracking/tracking_en_vivo_screen.dart';

class CotizacionesExpressScreen extends StatefulWidget {
  final int idIncidente;

  const CotizacionesExpressScreen({
    super.key,
    required this.idIncidente,
  });

  @override
  State<CotizacionesExpressScreen> createState() =>
      _CotizacionesExpressScreenState();
}

class _CotizacionesExpressScreenState
    extends State<CotizacionesExpressScreen> {
  final _service = CotizacionExpressService();
  Timer? _timer;
  List<SolicitudCotizacion> _solicitudes = [];
  bool _cargando = true;
  bool _consultando = false;
  bool _aceptando = false;
  String? _error;
  AceptacionCotizacion? _aceptacion;
  OfertaCotizacion? _ofertaGanadora;
  DateTime? _ultimaConsulta;

  @override
  void initState() {
    super.initState();
    _consultar();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _consultar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SolicitudCotizacion? get _solicitudActual {
    if (_solicitudes.isEmpty) return null;
    return _solicitudes.first;
  }

  Future<void> _consultar({bool silencioso = false}) async {
    if (_consultando || _aceptacion != null) return;
    _consultando = true;

    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final solicitudes =
          await _service.consultarOfertas(widget.idIncidente);
      if (!mounted) return;

      OfertaCotizacion? aceptada;
      for (final solicitud in solicitudes) {
        for (final oferta in solicitud.ofertas) {
          if (oferta.fueAceptada) {
            aceptada = oferta;
            break;
          }
        }
        if (aceptada != null) break;
      }

      setState(() {
        _solicitudes = solicitudes;
        _ofertaGanadora = aceptada;
        _ultimaConsulta = DateTime.now();
        _cargando = false;
        _error = null;
      });

      final estado = _solicitudActual?.estado;
      if (estado == 'FINALIZADA' || estado == 'VENCIDA') {
        _timer?.cancel();
      }
    } on CotizacionExpressException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error ${e.statusCode}: ${e.message}';
      });
      if (e.statusCode == 400 ||
          e.statusCode == 401 ||
          e.statusCode == 403) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error de conexion: $e';
      });
    } finally {
      _consultando = false;
    }
  }

  Future<void> _confirmarOferta(OfertaCotizacion oferta) async {
    if (_aceptando || _ofertaGanadora != null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Aceptar cotizacion'),
        content: Text(
          'Se asignara ${oferta.taller.nombre} por '
          'Bs ${oferta.montoEstimado.toStringAsFixed(2)}. '
          'Solo puedes aceptar una oferta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar oferta'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _aceptando = true;
      _error = null;
    });

    try {
      final aceptacion = await _service.aceptarOferta(oferta.id);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _aceptacion = aceptacion;
        _ofertaGanadora = oferta;
        _aceptando = false;
      });
    } on CotizacionExpressException catch (e) {
      if (!mounted) return;
      setState(() {
        _aceptando = false;
        _error = 'Error ${e.statusCode}: ${e.message}';
      });
      if (e.statusCode == 409) {
        Timer.run(() => _consultar());
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aceptando = false;
        _error = 'Error de conexion: $e';
      });
    }
  }

  void _continuarSeguimiento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingEnVivoScreen(
          idIncidente: widget.idIncidente,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cotizacion Express',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _consultando ? null : () => _consultar(),
            icon: _consultando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
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

    final solicitud = _solicitudActual;
    final ofertas = solicitud?.ofertas ?? [];

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: () => _consultar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _encabezado(solicitud),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _avisoError(_error!),
          ],
          if (_ofertaGanadora != null) ...[
            const SizedBox(height: 16),
            _ganador(_ofertaGanadora!),
          ] else if (solicitud == null || ofertas.isEmpty) ...[
            const SizedBox(height: 36),
            _esperandoOfertas(solicitud),
          ] else ...[
            const SizedBox(height: 18),
            Text(
              'Ofertas recibidas',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...ofertas.map((oferta) => _tarjetaOferta(solicitud, oferta)),
          ],
          const SizedBox(height: 20),
          if (_ultimaConsulta != null)
            Text(
              'Ultima actualizacion: ${_hora(_ultimaConsulta!)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _encabezado(SolicitudCotizacion? solicitud) {
    final estado = solicitud?.estado ?? 'ABIERTA';
    final color = _colorEstado(estado);
    final vencimiento = solicitud?.fechaVencimiento;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconoEstado(estado), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tituloEstado(estado),
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Incidente #${widget.idIncidente}'
                  '${solicitud == null ? '' : ' - Ronda ${solicitud.ronda}'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          _chipEstado(estado, color),
        ]),
        if (vencimiento != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.timer_outlined, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Vence: ${_fecha(vencimiento)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _tarjetaOferta(
    SolicitudCotizacion solicitud,
    OfertaCotizacion oferta,
  ) {
    final disponible = !_aceptando &&
        _ofertaGanadora == null &&
        !solicitud.estaFinalizada &&
        !solicitud.estaVencida;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.home_repair_service_outlined,
              color: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oferta.taller.nombre,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (oferta.taller.direccion.isNotEmpty)
                  Text(
                    oferta.taller.direccion,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            'Bs ${oferta.montoEstimado.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFFFFB020),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _dato(Icons.route_outlined,
              '${oferta.distanciaKm.toStringAsFixed(1)} km'),
          _dato(Icons.directions_car_outlined,
              '${oferta.tiempoLlegadaMinutos} min llegada'),
          _dato(Icons.build_outlined,
              '${oferta.tiempoReparacionMinutos} min reparacion'),
          if (oferta.taller.telefono.isNotEmpty)
            _dato(Icons.phone_outlined, oferta.taller.telefono),
        ]),
        const SizedBox(height: 14),
        Text(
          oferta.descripcionServicio,
          style: TextStyle(color: Colors.grey[300], height: 1.35),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed:
                disponible ? () => _confirmarOferta(oferta) : null,
            icon: _aceptando
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Aceptar esta oferta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _ganador(OfertaCotizacion oferta) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D9E75).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1D9E75)),
      ),
      child: Column(children: [
        const Icon(
          Icons.verified_outlined,
          size: 52,
          color: Color(0xFF1D9E75),
        ),
        const SizedBox(height: 12),
        Text(
          'Taller asignado',
          style: GoogleFonts.outfit(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          oferta.taller.nombre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _aceptacion?.mensaje ??
              'La cotizacion fue aceptada. El servicio puede continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _continuarSeguimiento,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Continuar al seguimiento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _esperandoOfertas(SolicitudCotizacion? solicitud) {
    final vencida = solicitud?.estaVencida == true;
    final finalizada = solicitud?.estaFinalizada == true;

    return Column(children: [
      Icon(
        vencida
            ? Icons.timer_off_outlined
            : finalizada
                ? Icons.task_alt
                : Icons.manage_search_outlined,
        size: 68,
        color: vencida ? Colors.redAccent : const Color(0xFFFF6B35),
      ),
      const SizedBox(height: 16),
      Text(
        vencida
            ? 'Solicitud vencida'
            : finalizada
                ? 'Cotizacion finalizada'
                : 'Esperando ofertas',
        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        vencida
            ? 'La ronda termino sin una oferta disponible.'
            : finalizada
                ? 'La ronda ya fue cerrada.'
                : 'Los talleres cercanos pueden responder. Esta pantalla se actualiza automaticamente.',
        style: TextStyle(color: Colors.grey[500], height: 1.4),
        textAlign: TextAlign.center,
      ),
      if (!vencida && !finalizada) ...[
        const SizedBox(height: 20),
        const CircularProgressIndicator(
          color: Color(0xFFFF6B35),
          strokeWidth: 2,
        ),
      ],
    ]);
  }

  Widget _avisoError(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }

  Widget _dato(IconData icon, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 5),
        Text(texto, style: TextStyle(color: Colors.grey[300], fontSize: 11)),
      ]),
    );
  }

  Widget _chipEstado(String estado, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'CON_RESPUESTAS':
        return const Color(0xFF1D9E75);
      case 'FINALIZADA':
        return const Color(0xFF4CAF50);
      case 'VENCIDA':
        return Colors.redAccent;
      default:
        return const Color(0xFFFF6B35);
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'CON_RESPUESTAS':
        return Icons.request_quote_outlined;
      case 'FINALIZADA':
        return Icons.task_alt;
      case 'VENCIDA':
        return Icons.timer_off_outlined;
      default:
        return Icons.hourglass_top;
    }
  }

  String _tituloEstado(String estado) {
    switch (estado) {
      case 'CON_RESPUESTAS':
        return 'Tienes ofertas disponibles';
      case 'FINALIZADA':
        return 'Cotizacion finalizada';
      case 'VENCIDA':
        return 'Cotizacion vencida';
      default:
        return 'Buscando cotizaciones';
    }
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }

  String _hora(DateTime fecha) {
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    final segundo = fecha.second.toString().padLeft(2, '0');
    return '$hora:$minuto:$segundo';
  }
}
