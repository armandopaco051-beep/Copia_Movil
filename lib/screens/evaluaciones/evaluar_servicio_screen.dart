import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/evaluacion.dart';
import '../../services/evaluacion_service.dart';

class EvaluarServicioScreen extends StatefulWidget {
  final int idIncidente;

  const EvaluarServicioScreen({super.key, required this.idIncidente});

  @override
  State<EvaluarServicioScreen> createState() => _EvaluarServicioScreenState();
}

class _EvaluarServicioScreenState extends State<EvaluarServicioScreen> {
  final _service = EvaluacionService();
  final _comentarioCtrl = TextEditingController();
  EvaluacionServicio? _evaluacion;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  String? _mensaje;

  int _calificacion = 5;
  int _puntualidad = 5;
  int _trato = 5;
  int _solucion = 5;
  int _precio = 5;

  @override
  void initState() {
    super.initState();
    _consultarEvaluacion(inicial: true);
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _consultarEvaluacion({bool inicial = false}) async {
    if (inicial) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final evaluacion = await _service.consultar(widget.idIncidente);
      if (!mounted) return;
      setState(() {
        _evaluacion = evaluacion;
        _cargando = false;
        _mensaje = 'Este servicio ya fue evaluado';
      });
    } on EvaluacionServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (e.statusCode == 404) {
          _evaluacion = null;
          _mensaje = null;
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _enviarEvaluacion() async {
    setState(() {
      _enviando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      final resultado = await _service.crear(
        idIncidente: widget.idIncidente,
        calificacion: _calificacion,
        comentario: _comentarioCtrl.text.trim(),
        puntualidad: _puntualidad,
        trato: _trato,
        solucion: _solucion,
        precio: _precio,
      );
      if (!mounted) return;
      setState(() {
        _evaluacion = resultado.evaluacion;
        _mensaje = resultado.mensaje;
        _enviando = false;
      });
    } on EvaluacionServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.message;
      });
      if (e.statusCode == 400 && e.message.toLowerCase().contains('evalu')) {
        await _consultarEvaluacion();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Evaluar servicio',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Consultar evaluacion',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : () => _consultarEvaluacion(),
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

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: () => _consultarEvaluacion(),
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
          _encabezado(),
          const SizedBox(height: 16),
          if (_evaluacion == null) _formulario() else _evaluacionRegistrada(),
        ],
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.star_rate, color: Color(0xFFFF6B35)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Incidente #${widget.idIncidente}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _evaluacion == null
                  ? 'Disponible cuando el servicio este finalizado'
                  : 'Evaluacion registrada',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Calificacion general',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _rating(
          value: _calificacion,
          size: 36,
          onChanged: (v) => setState(() => _calificacion = v),
        ),
        const SizedBox(height: 22),
        _ratingFila('Puntualidad', _puntualidad,
            (v) => setState(() => _puntualidad = v)),
        _ratingFila('Trato', _trato, (v) => setState(() => _trato = v)),
        _ratingFila('Solucion', _solucion, (v) => setState(() => _solucion = v)),
        _ratingFila('Precio', _precio, (v) => setState(() => _precio = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _comentarioCtrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comentario',
            hintText: 'Ej: El tecnico llego rapido y soluciono el problema.',
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _enviando ? null : _enviarEvaluacion,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar evaluacion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _evaluacionRegistrada() {
    final evaluacion = _evaluacion!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Tu evaluacion',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            _formatearFecha(evaluacion.fechaEvaluacion),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ]),
        const SizedBox(height: 12),
        _rating(value: evaluacion.calificacion, size: 32),
        const SizedBox(height: 18),
        _detalleRating('Puntualidad', evaluacion.puntualidad),
        _detalleRating('Trato', evaluacion.trato),
        _detalleRating('Solucion', evaluacion.solucion),
        _detalleRating('Precio', evaluacion.precio),
        if (evaluacion.comentario.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              evaluacion.comentario,
              style: TextStyle(color: Colors.grey[300], height: 1.35),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _filaTexto('Tecnico', evaluacion.codigoTecnico),
        _filaTexto('Taller', '#${evaluacion.idTaller}'),
      ]),
    );
  }

  Widget _ratingFila(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        _rating(value: value, size: 24, onChanged: onChanged),
      ]),
    );
  }

  Widget _detalleRating(String label, int? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey[400])),
        ),
        _rating(value: value ?? 0, size: 20),
      ]),
    );
  }

  Widget _rating({
    required int value,
    required double size,
    ValueChanged<int>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= value;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              color: const Color(0xFFFFB020),
              size: size,
            ),
          ),
        );
      }),
    );
  }

  Widget _filaTexto(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? 'No disponible' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ]),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}
