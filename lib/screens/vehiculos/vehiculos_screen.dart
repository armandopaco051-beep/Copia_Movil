import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/vehiculo.dart';
import '../../models/usuario.dart';
import '../../services/vehiculo_service.dart';
import '../../services/auth_service.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});
  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  List<Vehiculo> _vehiculos = [];
  Usuario? _usuario;
  bool _loading = true;
  String? _error;
  final _svc = VehiculoService();

  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _placa = TextEditingController();
  final _anio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usuario = await AuthService().getUsuarioActual();

      if (!mounted) return;

      if (usuario == null) {
        setState(() {
          _usuario = null;
          _vehiculos = [];
          _loading = false;
          _error =
              'No se encontró el usuario logueado. Cierra sesión e inicia otra vez.';
        });
        return;
      }

      final lista = await _svc.listarPorUsuario(usuario.codigo);

      if (!mounted) return;

      setState(() {
        _usuario = usuario;
        _vehiculos = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Error al cargar vehículos: $e';
      });
    }
  }

  void _abrirFormulario([Vehiculo? v]) {
    _marca.text = v?.marca ?? '';
    _modelo.text = v?.modelo ?? '';
    _placa.text = v?.placa ?? '';
    _anio.text = v?.anio ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(v == null ? 'Nuevo Vehículo' : 'Editar Vehículo',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _campoModal('Marca', _marca, Icons.directions_car)),
              const SizedBox(width: 12),
              Expanded(child: _campoModal('Modelo', _modelo, Icons.car_repair)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _campoModal('Placa', _placa, Icons.badge_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _campoModal(
                      'Año', _anio, Icons.calendar_today_outlined,
                      tipo: TextInputType.number)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (v == null) {
                    await _svc.crear(
                        marca: _marca.text,
                        modelo: _modelo.text,
                        placa: _placa.text,
                        anio: _anio.text,
                        idUsuario: _usuario!.codigo);
                  } else {
                    await _svc.actualizar(codigo: v.codigo, datos: {
                      'marca': _marca.text,
                      'modelo': _modelo.text,
                      'placa': _placa.text,
                      'año': _anio.text,
                    });
                  }
                  _cargar();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(
                    v == null ? 'Registrar Vehículo' : 'Guardar Cambios',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _eliminar(Vehiculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Eliminar vehículo'),
        content: Text('¿Eliminar ${v.marca} ${v.modelo}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.eliminar(v.codigo);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Vehículos',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFFF6B35), size: 28),
              onPressed: () => _abrirFormulario()),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _cargar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _vehiculos.isEmpty
                  ? _estadoVacio()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _vehiculos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _tarjetaVehiculo(_vehiculos[i]),
                    ),
    );
  }

  Widget _tarjetaVehiculo(Vehiculo v) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.directions_car,
              color: Color(0xFFFF6B35), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v.marca} ${v.modelo}',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              _chip(Icons.badge_outlined, v.placa),
              const SizedBox(width: 10),
              _chip(Icons.calendar_today_outlined, v.anio),
            ]),
          ]),
        ),
        PopupMenuButton<String>(
          color: const Color(0xFF1C2128),
          onSelected: (val) {
            if (val == 'editar') _abrirFormulario(v);
            if (val == 'eliminar') _eliminar(v);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'editar',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFF6B35)),
                  SizedBox(width: 8),
                  Text('Editar')
                ])),
            const PopupMenuItem(
                value: 'eliminar',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red))
                ])),
          ],
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String texto) {
    return Row(children: [
      Icon(icon, size: 12, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(texto, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ]);
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text('Sin vehículos',
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Registra tu primer vehículo',
            style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar vehículo'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _campoModal(String label, TextEditingController ctrl, IconData icon,
      {TextInputType tipo = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 18)),
    );
  }
}
