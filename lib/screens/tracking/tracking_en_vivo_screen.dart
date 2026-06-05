import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../models/tracking.dart';
import '../../services/tracking_service.dart';
import '../chat/chat_incidente_screen.dart';
import '../evaluaciones/evaluar_servicio_screen.dart';
import '../pagos/pago_servicio_screen.dart';
import '../validacion/codigo_arribo_screen.dart';

class TrackingEnVivoScreen extends StatefulWidget {
  final int idIncidente;

  const TrackingEnVivoScreen({super.key, required this.idIncidente});

  @override
  State<TrackingEnVivoScreen> createState() => _TrackingEnVivoScreenState();
}

class _TrackingEnVivoScreenState extends State<TrackingEnVivoScreen> {
  final _service = TrackingService();
  Timer? _timer;
  EtaTracking? _eta;
  UltimaUbicacionTecnico? _ultimaUbicacion;
  bool _cargando = true;
  bool _actualizando = false;
  String? _error;
  DateTime? _ultimaConsulta;

  @override
  void initState() {
    super.initState();
    _cargarTracking();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cargarTracking(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarTracking({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    } else {
      setState(() => _actualizando = true);
    }

    try {
      final eta = await _service.obtenerEta(widget.idIncidente);
      UltimaUbicacionTecnico? ultima;

      try {
        ultima = await _service.obtenerUltimaUbicacion(widget.idIncidente);
      } catch (_) {
        ultima = null;
      }

      if (!mounted) return;
      setState(() {
        _eta = eta;
        _ultimaUbicacion = ultima;
        _ultimaConsulta = DateTime.now();
        _cargando = false;
        _actualizando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _actualizando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ubicacion en vivo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Evaluar',
            icon: const Icon(Icons.star_rate_outlined),
            onPressed: _abrirEvaluacion,
          ),
          IconButton(
            tooltip: 'Pago',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _abrirPago,
          ),
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _abrirChat,
          ),
          IconButton(
            tooltip: 'PIN o QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: _abrirCodigoArribo,
          ),
          IconButton(
            onPressed: _actualizando ? null : () => _cargarTracking(),
            icon: _actualizando
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

    if (_error != null && _eta == null) {
      return _estadoError(_error!);
    }

    final eta = _eta;
    if (eta == null) return _estadoVacio();

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: () => _cargarTracking(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _mapa(eta),
          const SizedBox(height: 16),
          _resumen(eta),
          const SizedBox(height: 16),
          _evaluacionButton(),
          const SizedBox(height: 16),
          _pagoButton(),
          const SizedBox(height: 16),
          _chatButton(),
          const SizedBox(height: 16),
          _codigoArriboButton(),
          const SizedBox(height: 16),
          _detalleTecnico(eta),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _aviso(_error!),
          ],
        ],
      ),
    );
  }

  Widget _mapa(EtaTracking eta) {
    final tecnico = _puntoTecnico(eta);
    final cliente = LatLng(
      eta.ubicacionCliente.latitud,
      eta.ubicacionCliente.longitud,
    );
    final centro = LatLng(
      (tecnico.latitude + cliente.latitude) / 2,
      (tecnico.longitude + cliente.longitude) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 360,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tallermovil',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [tecnico, cliente],
                    color: const Color(0xFFFF6B35),
                    strokeWidth: 4,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: tecnico,
                    width: 56,
                    height: 56,
                    child: _marker(
                      icon: Icons.engineering,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                  Marker(
                    point: cliente,
                    width: 56,
                    height: 56,
                    child: _marker(
                      icon: Icons.person_pin_circle,
                      color: const Color(0xFF1D9E75),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _mapBadge(eta.vigente ? 'En vivo' : 'Sin actualizar'),
          ),
        ]),
      ),
    );
  }

  Widget _marker({required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }

  Widget _mapBadge(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withOpacity(0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF1D9E75),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _resumen(EtaTracking eta) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Incidente #${eta.idIncidente}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _estadoChip(eta.estado),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _dato('ETA', '${eta.etaMinutos} min'),
          const SizedBox(width: 10),
          _dato('Distancia', '${eta.distanciaKm.toStringAsFixed(2)} km'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _dato(
            'Velocidad',
            '${eta.velocidadPromedioKmh.toStringAsFixed(0)} km/h',
          ),
          const SizedBox(width: 10),
          _dato('Vigente', eta.vigente ? 'Si' : 'No'),
        ]),
      ]),
    );
  }

  Widget _detalleTecnico(EtaTracking eta) {
    final ultima = _ultimaUbicacion;
    final fecha = ultima?.fecha ?? eta.ubicacionTecnico.fecha;
    final segundos = eta.ubicacionTecnico.segundosDesdeActualizacion;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Tecnico asignado',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _filaDetalle(Icons.badge_outlined, 'Codigo', eta.codigoTecnico),
        _filaDetalle(
          Icons.route_outlined,
          'Asignacion',
          '#${eta.idAsignacion}',
        ),
        _filaDetalle(
          Icons.location_on_outlined,
          'Coordenadas',
          '${_puntoTecnico(eta).latitude.toStringAsFixed(5)}, '
              '${_puntoTecnico(eta).longitude.toStringAsFixed(5)}',
        ),
        _filaDetalle(
          Icons.access_time,
          'Actualizado',
          segundos > 0 ? 'hace $segundos s' : _formatearFecha(fecha),
        ),
        _filaDetalle(
          Icons.sync,
          'Consulta',
          _formatearFecha(_ultimaConsulta),
        ),
      ]),
    );
  }

  Widget _codigoArriboButton() {
    return GestureDetector(
      onTap: _abrirCodigoArribo,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2, color: Color(0xFFFF6B35)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN o QR de validacion',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Muestralo cuando el tecnico llegue',
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

  Widget _chatButton() {
    return GestureDetector(
      onTap: _abrirChat,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat con tecnico',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordina detalles del servicio',
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

  Widget _pagoButton() {
    return GestureDetector(
      onTap: _abrirPago,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago y comprobante',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa el cobro del servicio',
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

  Widget _evaluacionButton() {
    return GestureDetector(
      onTap: _abrirEvaluacion,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
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
                  'Califica cuando el servicio finalice',
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

  Widget _dato(String label, String valor) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }

  Widget _filaDetalle(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            valor.isEmpty ? 'No disponible' : valor,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _estadoChip(String estado) {
    final color = estado.toLowerCase().contains('camino')
        ? const Color(0xFFFF6B35)
        : const Color(0xFF1D9E75);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_off_outlined,
              color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la ubicacion',
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
            onPressed: () => _cargarTracking(),
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
          Icon(Icons.map_outlined, color: Colors.grey[600], size: 58),
          const SizedBox(height: 16),
          Text(
            'Sin ubicacion disponible',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    );
  }

  Widget _aviso(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.30)),
      ),
      child: Text(mensaje, style: const TextStyle(color: Colors.orange)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    );
  }

  LatLng _puntoTecnico(EtaTracking eta) {
    final ultima = _ultimaUbicacion;
    if (ultima != null) return LatLng(ultima.latitud, ultima.longitud);
    return LatLng(
      eta.ubicacionTecnico.latitud,
      eta.ubicacionTecnico.longitud,
    );
  }

  void _abrirCodigoArribo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CodigoArriboScreen(idIncidente: widget.idIncidente),
      ),
    );
  }

  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatIncidenteScreen(idIncidente: widget.idIncidente),
      ),
    );
  }

  void _abrirPago() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoServicioScreen(idIncidente: widget.idIncidente),
      ),
    );
  }

  void _abrirEvaluacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluarServicioScreen(idIncidente: widget.idIncidente),
      ),
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No disponible';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}
