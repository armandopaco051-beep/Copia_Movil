import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/validacion_arribo.dart';
import '../../services/validacion_arribo_service.dart';

class CodigoArriboScreen extends StatefulWidget {
  final int idIncidente;

  const CodigoArriboScreen({super.key, required this.idIncidente});

  @override
  State<CodigoArriboScreen> createState() => _CodigoArriboScreenState();
}

class _CodigoArriboScreenState extends State<CodigoArriboScreen> {
  late Future<ValidacionArribo> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = ValidacionArriboService().obtenerCodigo(widget.idIncidente);
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
          'Validar arribo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar codigo',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_cargar),
          ),
        ],
      ),
      body: FutureBuilder<ValidacionArribo>(
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

          final codigo = snapshot.data;
          if (codigo == null) return _estadoVacio();

          return RefreshIndicator(
            color: const Color(0xFFFF6B35),
            onRefresh: _refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _encabezado(codigo),
                const SizedBox(height: 18),
                _pin(codigo),
                const SizedBox(height: 18),
                _qr(codigo),
                const SizedBox(height: 18),
                _detalle(codigo),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(ValidacionArribo codigo) {
    final estadoColor = codigo.usado || codigo.vencido
        ? const Color(0xFFF44336)
        : const Color(0xFF1D9E75);
    final estadoTexto = codigo.usado
        ? 'Usado'
        : codigo.vencido
            ? 'Vencido'
            : 'Vigente';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: estadoColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.verified_user_outlined, color: estadoColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Incidente #${codigo.idIncidente}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Muestra este codigo cuando llegue el tecnico',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ]),
        ),
        _estadoChip(estadoTexto, estadoColor),
      ]),
    );
  }

  Widget _pin(ValidacionArribo codigo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(children: [
        Text(
          'PIN de validacion',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6B35)),
          ),
          child: Text(
            _formatearPin(codigo.pin),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: const Color(0xFFFF6B35),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _qr(ValidacionArribo codigo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(children: [
        Text(
          'QR de validacion',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (codigo.qrToken.isEmpty)
          Text(
            'QR no disponible',
            style: TextStyle(color: Colors.grey[500]),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: codigo.qrToken,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'El tecnico puede escanearlo o ingresar el PIN.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _detalle(ValidacionArribo codigo) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Detalle',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _fila(Icons.assignment_outlined, 'Asignacion', '#${codigo.idAsignacion}'),
        _fila(Icons.timer_outlined, 'Vigencia', '${codigo.vigenciaMinutos} min'),
        _fila(
          Icons.hourglass_bottom,
          'Restante',
          codigo.vencido ? 'Vencido' : '${codigo.minutosRestantes} min',
        ),
        _fila(
          Icons.schedule,
          'Expira',
          _formatearFecha(codigo.fechaExpiracion),
        ),
      ]),
    );
  }

  Widget _fila(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _estadoChip(String estado, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        estado,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _estadoError(String mensaje) {
    final limpio = mensaje.replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_2_outlined, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text(
            'No se pudo obtener el codigo',
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
      child: Text(
        'Codigo no disponible',
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    );
  }

  String _formatearPin(String pin) {
    if (pin.length <= 3) return pin;
    return '${pin.substring(0, 3)} ${pin.substring(3)}';
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
