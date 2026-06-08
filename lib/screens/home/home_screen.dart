import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/notificacion_service.dart';
import '../../services/offline_sync_service.dart';
import '../perfil/perfil_screen.dart';
import '../vehiculos/vehiculos_screen.dart';
import '../emergencia/emergencia_screen.dart';
import '../evaluaciones/evaluar_servicio_screen.dart';
import '../incidentes/linea_tiempo_screen.dart';
import '../notificaciones/notificaciones_screen.dart';
import '../offline/offline_pendientes_screen.dart';
import '../pagos/pago_servicio_screen.dart';
import '../tracking/tracking_en_vivo_screen.dart';
import '../validacion/codigo_arribo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;
  Usuario? _usuario;
  int _notificacionesNoLeidas = 0;
  int _offlinePendientes = 0;
  bool _sincronizandoOffline = false;
  Timer? _notificacionesTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _cargarContadorNotificaciones();
    _cargarPendientesOffline();
    _notificacionesTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _cargarContadorNotificaciones(),
    );
    // CU-OFF-11: Detectar regreso de conexion y sincronizar pendientes.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((estados) {
      if (estados.any((estado) => estado != ConnectivityResult.none)) {
        _sincronizarPendientes(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _notificacionesTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthService().getUsuarioActual();
    if (!mounted) return;
    setState(() => _usuario = u);
  }

  Future<void> _cargarContadorNotificaciones() async {
    try {
      final total = await NotificacionService().contarNoLeidas();
      if (!mounted) return;
      setState(() => _notificacionesNoLeidas = total);
    } catch (_) {}
  }

  Future<void> _cargarPendientesOffline() async {
    final total = await OfflineSyncService().contarPendientes();
    if (!mounted) return;
    setState(() => _offlinePendientes = total);
  }

  Future<void> _abrirPendientesOffline() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfflinePendientesScreen()),
    );
    if (!mounted) return;
    _cargarPendientesOffline();
  }

  Future<void> _sincronizarPendientes({bool silencioso = false}) async {
    if (_sincronizandoOffline || _offlinePendientes == 0) return;
    setState(() => _sincronizandoOffline = true);
    final resultado = await OfflineSyncService().sincronizarPendientes();
    await _cargarPendientesOffline();
    if (!mounted) return;
    setState(() => _sincronizandoOffline = false);

    if (!silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Sincronizados: ${resultado.sincronizados}. Parciales: ${resultado.parciales}. Conflictos: ${resultado.conflictos}. Errores: ${resultado.conError}.',
        ),
        backgroundColor: resultado.conError == 0 && resultado.conflictos == 0
            ? const Color(0xFF1D9E75)
            : Colors.orange,
      ));
    }
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
    );
    if (!mounted) return;
    _cargarContadorNotificaciones();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(
          usuario: _usuario,
          notificacionesNoLeidas: _notificacionesNoLeidas,
          offlinePendientes: _offlinePendientes,
          sincronizandoOffline: _sincronizandoOffline,
          onNotificaciones: _abrirNotificaciones,
          onPendientesOffline: _abrirPendientesOffline,
          onSincronizarPendientes: () => _sincronizarPendientes(),
          onEmergencia: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EmergenciaScreen()));
          }),
      const VehiculosScreen(),
      const PerfilScreen(),
    ];

    return Scaffold(
      body: tabs[_tabActual],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF161B22),
        indicatorColor: const Color(0xFFFF6B35).withOpacity(0.2),
        selectedIndex: _tabActual,
        onDestinationSelected: (i) => setState(() => _tabActual = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFFFF6B35)),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon:
                  Icon(Icons.directions_car, color: Color(0xFFFF6B35)),
              label: 'Vehículos'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFFFF6B35)),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final Usuario? usuario;
  final int notificacionesNoLeidas;
  final int offlinePendientes;
  final bool sincronizandoOffline;
  final VoidCallback onNotificaciones;
  final VoidCallback onPendientesOffline;
  final VoidCallback onSincronizarPendientes;
  final VoidCallback onEmergencia;
  const _HomeTab({
    this.usuario,
    required this.notificacionesNoLeidas,
    required this.offlinePendientes,
    required this.sincronizandoOffline,
    required this.onNotificaciones,
    required this.onPendientesOffline,
    required this.onSincronizarPendientes,
    required this.onEmergencia,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hola, ${usuario?.nombre ?? ''}',
                  style: GoogleFonts.outfit(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text('¿Necesitas asistencia?',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ]),
            Row(children: [
              _campanaNotificaciones(),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFF6B35),
                child: Text(_inicialUsuario(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
          const SizedBox(height: 32),

          // BOTÓN EMERGENCIA GRANDE
          GestureDetector(
            onTap: onEmergencia,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 56, color: Colors.white),
                const SizedBox(height: 14),
                Text('REPORTAR EMERGENCIA',
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('Pulsa para pedir ayuda inmediata',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          if (offlinePendientes > 0) ...[
            // CU-OFF-12: Mostrar etiqueta Offline/Pendiente y boton sincronizar.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onPendientesOffline,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$offlinePendientes reporte(s) offline',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text('Pendientes de sincronizacion',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                        ]),
                  ),
                ),
                IconButton(
                  onPressed:
                      sincronizandoOffline ? null : onSincronizarPendientes,
                  icon: sincronizandoOffline
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        )
                      : const Icon(Icons.sync, color: Colors.orange),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          GestureDetector(
            onTap: () => _abrirConsultaLineaTiempo(context),
            child: Container(
              width: double.infinity,
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
                    color: const Color(0xFFFF6B35).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.timeline,
                      color: Color(0xFFFF6B35), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consultar servicio',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Revisa la linea de tiempo por incidente',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () => _abrirTrackingEnVivo(context),
            child: Container(
              width: double.infinity,
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
                    color: const Color(0xFF1D9E75).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Color(0xFF1D9E75), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubicacion en vivo',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Mira al tecnico en el mapa',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () => _abrirCodigoArribo(context),
            child: Container(
              width: double.infinity,
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
                    color: const Color(0xFF0F3460).withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIN o QR de arribo',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Muestralo para validar la llegada',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () => _abrirPagoServicio(context),
            child: Container(
              width: double.infinity,
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
                    color: const Color(0xFFFF6B35).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFFFF6B35), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pago y comprobante',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Consulta el cobro por incidente',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () => _abrirEvaluacionServicio(context),
            child: Container(
              width: double.infinity,
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
                  child: const Icon(Icons.star_rate_outlined,
                      color: Color(0xFFFFB020), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Evaluar servicio',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Consulta o registra tu calificacion',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          Text('Tipos de Emergencia',
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              _tipoCard('🔋', 'Batería'),
              _tipoCard('🛞', 'Llanta'),
              _tipoCard('⚙️', 'Motor'),
              _tipoCard('🚗', 'Choque'),
              _tipoCard('⛽', 'Combustible'),
              _tipoCard('🔑', 'Cerrajería'),
            ],
          ),
          const SizedBox(height: 24),

          Text('Información',
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _infoCard(Icons.access_time, 'Disponible 24/7',
              'Asistencia en cualquier momento'),
          const SizedBox(height: 10),
          _infoCard(Icons.location_on_outlined, 'GPS en tiempo real',
              'Te ubicamos automáticamente'),
          const SizedBox(height: 10),
          _infoCard(Icons.smart_toy_outlined, 'IA integrada',
              'Diagnóstico automático del problema'),
        ]),
      ),
    );
  }

  Widget _tipoCard(String emoji, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]),
    );
  }

  String _inicialUsuario() {
    final nombre = usuario?.nombre.trim();
    if (nombre == null || nombre.isEmpty) return 'U';
    return nombre.substring(0, 1).toUpperCase();
  }

  Widget _campanaNotificaciones() {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: onNotificaciones,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (notificacionesNoLeidas > 0)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    notificacionesNoLeidas > 99
                        ? '99+'
                        : notificacionesNoLeidas.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _abrirConsultaLineaTiempo(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Consultar servicio'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de incidente',
            hintText: 'Ej: 15',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              if (valor == null) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (id == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineaTiempoScreen(idIncidente: id),
      ),
    );
  }

  Future<void> _abrirTrackingEnVivo(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Ubicacion en vivo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de incidente',
            hintText: 'Ej: 15',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              if (valor == null) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver mapa'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (id == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingEnVivoScreen(idIncidente: id),
      ),
    );
  }

  Future<void> _abrirCodigoArribo(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('PIN o QR de arribo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de incidente',
            hintText: 'Ej: 15',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              if (valor == null) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver codigo'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (id == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CodigoArriboScreen(idIncidente: id),
      ),
    );
  }

  Future<void> _abrirPagoServicio(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Pago y comprobante'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de incidente',
            hintText: 'Ej: 25',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              if (valor == null) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver pago'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (id == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoServicioScreen(idIncidente: id),
      ),
    );
  }

  Future<void> _abrirEvaluacionServicio(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Evaluar servicio'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de incidente',
            hintText: 'Ej: 10',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = int.tryParse(controller.text.trim());
              if (valor == null) return;
              Navigator.pop(dialogContext, valor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB020),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (id == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluarServicioScreen(idIncidente: id),
      ),
    );
  }

  Widget _infoCard(IconData icon, String titulo, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFF6B35), size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ]),
      ]),
    );
  }
}
