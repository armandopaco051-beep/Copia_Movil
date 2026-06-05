import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/pago.dart';
import '../../services/pago_service.dart';
import '../evaluaciones/evaluar_servicio_screen.dart';

class PagoServicioScreen extends StatefulWidget {
  final int idIncidente;

  const PagoServicioScreen({super.key, required this.idIncidente});

  @override
  State<PagoServicioScreen> createState() => _PagoServicioScreenState();
}

class _PagoServicioScreenState extends State<PagoServicioScreen> {
  final _service = PagoService();
  final _referenciaCtrl = TextEditingController();
  ResumenCobro? _resumen;
  ComprobantePago? _comprobante;
  String _metodoPago = 'QR';
  bool _cargando = true;
  bool _accionando = false;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  @override
  void dispose() {
    _referenciaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _cargando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final resumen = await _service.obtenerResumen(widget.idIncidente);
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
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

  Future<void> _aceptarMonto() async {
    setState(() {
      _accionando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final resumen = await _service.aceptarMonto(widget.idIncidente);
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _accionando = false;
        _mensaje = 'Monto aceptado correctamente';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accionando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _registrarPago() async {
    final referencia = _referenciaCtrl.text.trim();
    if (referencia.isEmpty) {
      setState(() => _error = 'Ingresa una referencia del pago');
      return;
    }

    setState(() {
      _accionando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final resultado = await _service.registrarPago(
        idIncidente: widget.idIncidente,
        metodoPago: _metodoPago,
        referenciaPago: referencia,
      );
      if (!mounted) return;
      setState(() {
        _comprobante = resultado.comprobante;
        _accionando = false;
        _mensaje = resultado.mensaje;
      });
      await _cargarResumen();
      if (mounted) {
        setState(() {
          _comprobante = resultado.comprobante;
          _mensaje = resultado.mensaje;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accionando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _consultarComprobante() async {
    setState(() {
      _accionando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final comprobante =
          await _service.obtenerComprobante(widget.idIncidente);
      if (!mounted) return;
      setState(() {
        _comprobante = comprobante;
        _accionando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accionando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool get _montoAceptado {
    final estado = _resumen?.estadoPago.toUpperCase() ?? '';
    return estado.contains('ACEPTADO') || estado.contains('PAGADO');
  }

  bool get _pagado {
    final estado = _resumen?.estadoPago.toUpperCase() ?? '';
    return estado.contains('PAGADO');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pago del servicio',
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
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargarResumen,
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

    if (_resumen == null) return _estadoError(_error ?? 'Cobro no disponible');

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: _cargarResumen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            _aviso(_error!, Colors.redAccent),
            const SizedBox(height: 12),
          ],
          if (_mensaje != null) ...[
            _aviso(_mensaje!, const Color(0xFF1D9E75)),
            const SizedBox(height: 12),
          ],
          _resumenCard(_resumen!),
          const SizedBox(height: 16),
          _conceptosCard(_resumen!.conceptos),
          const SizedBox(height: 16),
          _accionesCard(),
          if (_comprobante != null) ...[
            const SizedBox(height: 16),
            _comprobanteCard(_comprobante!),
          ],
        ],
      ),
    );
  }

  Widget _resumenCard(ResumenCobro resumen) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Incidente #${resumen.idIncidente}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _estadoChip(resumen.estadoPago),
        ]),
        const SizedBox(height: 16),
        _filaMonto('Subtotal', resumen.subtotal),
        _filaMonto('Descuento', resumen.descuento),
        const Divider(color: Color(0xFF30363D), height: 24),
        _filaMonto('Total', resumen.total, destacado: true),
      ]),
    );
  }

  Widget _conceptosCard(List<ConceptoCobro> conceptos) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Conceptos',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (conceptos.isEmpty)
          Text('Sin conceptos registrados',
              style: TextStyle(color: Colors.grey[500]))
        else
          ...conceptos.map(_conceptoItem),
      ]),
    );
  }

  Widget _conceptoItem(ConceptoCobro concepto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(
              concepto.descripcion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            _moneda(concepto.subtotal),
            style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '${concepto.cantidad.toStringAsFixed(0)} x '
          '${_moneda(concepto.precioUnitario)}',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        if (concepto.observacion.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            concepto.observacion,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ]),
    );
  }

  Widget _accionesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Acciones',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (!_montoAceptado)
          _boton(
            icon: Icons.check_circle_outline,
            texto: 'Aceptar monto',
            color: const Color(0xFF1D9E75),
            onPressed: _accionando ? null : _aceptarMonto,
          ),
        if (_montoAceptado && !_pagado) ...[
          _metodoPagoSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _referenciaCtrl,
            decoration: const InputDecoration(
              labelText: 'Referencia de pago',
              hintText: 'Ej: TXN-123456',
            ),
          ),
          const SizedBox(height: 12),
          _boton(
            icon: Icons.payments_outlined,
            texto: 'Registrar pago',
            color: const Color(0xFFFF6B35),
            onPressed: _accionando ? null : _registrarPago,
          ),
        ],
        if (_pagado || _comprobante != null) ...[
          if (!_montoAceptado) const SizedBox.shrink(),
          _boton(
            icon: Icons.receipt_long_outlined,
            texto: 'Ver comprobante',
            color: const Color(0xFF0F3460),
            onPressed: _accionando ? null : _consultarComprobante,
          ),
        ],
      ]),
    );
  }

  Widget _metodoPagoSelector() {
    final metodos = ['QR', 'EFECTIVO'];
    return Row(
      children: metodos.map((metodo) {
        final seleccionado = _metodoPago == metodo;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: metodo == metodos.last ? 0 : 10),
            child: ChoiceChip(
              selected: seleccionado,
              label: Center(child: Text(metodo)),
              onSelected: (_) => setState(() {
                _metodoPago = metodo;
                if (metodo == 'EFECTIVO') {
                  _referenciaCtrl.text = 'Pago recibido por el tecnico';
                } else {
                  _referenciaCtrl.clear();
                }
              }),
              selectedColor: const Color(0xFFFF6B35),
              backgroundColor: const Color(0xFF0D1117),
              labelStyle: TextStyle(
                color: seleccionado ? Colors.white : Colors.grey[300],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _comprobanteCard(ComprobantePago comprobante) {
    final detalle = comprobante.detalle;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, color: Color(0xFFFF6B35)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Comprobante',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _filaTexto('Numero', comprobante.numeroComprobante),
        _filaTexto('Emision', _formatearFecha(comprobante.fechaEmision)),
        _filaTexto('Estado', detalle?.estadoPago ?? 'PAGADO'),
        const Divider(color: Color(0xFF30363D), height: 24),
        _filaMonto('Total pagado', comprobante.total, destacado: true),
        if (detalle != null && detalle.conceptos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Detalle',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...detalle.conceptos.map(
            (c) => _filaTexto(c.descripcion, _moneda(c.subtotal)),
          ),
        ],
      ]),
    );
  }

  Widget _filaMonto(String label, double value, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(
          label,
          style: TextStyle(
            color: destacado ? Colors.white : Colors.grey[400],
            fontSize: destacado ? 16 : 14,
            fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          _moneda(value),
          style: TextStyle(
            color: destacado ? const Color(0xFFFF6B35) : Colors.white,
            fontSize: destacado ? 20 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  Widget _filaTexto(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 12),
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

  Widget _boton({
    required IconData icon,
    required String texto,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _accionando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final estadoUpper = estado.toUpperCase();
    final color = estadoUpper.contains('PAGADO')
        ? const Color(0xFF1D9E75)
        : estadoUpper.contains('ACEPTADO')
            ? const Color(0xFFFF6B35)
            : const Color(0xFF8B949E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
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

  Widget _aviso(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }

  Widget _estadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.payments_outlined, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar el pago',
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
            onPressed: _cargarResumen,
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    );
  }

  String _moneda(double value) {
    return 'Bs ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
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
