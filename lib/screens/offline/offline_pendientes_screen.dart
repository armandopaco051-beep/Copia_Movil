import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/incidente_local.dart';
import '../../models/sync_conflicto.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';

class OfflinePendientesScreen extends StatefulWidget {
  const OfflinePendientesScreen({super.key});

  @override
  State<OfflinePendientesScreen> createState() =>
      _OfflinePendientesScreenState();
}

class _OfflinePendientesScreenState extends State<OfflinePendientesScreen> {
  final OfflineSyncService _service = OfflineSyncService();
  bool _sincronizando = false;
  bool _cargandoConflictos = false;
  List<IncidenteLocal> _locales = [];
  List<SyncConflicto> _conflictosBackend = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final locales = await _service.listarPendientes();
    await _cargarConflictosBackend();
    if (!mounted) return;
    setState(() => _locales = locales);
  }

  Future<void> _cargarConflictosBackend() async {
    setState(() => _cargandoConflictos = true);
    try {
      final usuario = await AuthService().getUsuarioActual();
      final conflictos = await _service.listarConflictosPendientes(
        codigoUsuario: usuario?.codigo,
      );
      if (!mounted) return;
      setState(() => _conflictosBackend = conflictos);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _cargandoConflictos = false);
    }
  }

  Future<void> _sincronizar() async {
    // CU-OFF-13: Reintento manual desde pantalla "Sincronizacion".
    setState(() => _sincronizando = true);
    final resultado = await _service.sincronizarPendientes();
    await _cargar();
    if (!mounted) return;
    setState(() => _sincronizando = false);

    final mensaje = 'Sincronizados: ${resultado.sincronizados}. '
        'Parciales: ${resultado.parciales}. '
        'Conflictos: ${resultado.conflictos}. '
        'Errores: ${resultado.conError}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: resultado.conError == 0 && resultado.conflictos == 0
          ? const Color(0xFF1D9E75)
          : Colors.orange,
    ));
  }

  Future<void> _resolverConflicto(
    SyncConflicto conflicto,
    String accion,
  ) async {
    final usuario = await AuthService().getUsuarioActual();
    try {
      await _service.resolverConflicto(
        idConflicto: conflicto.id,
        accion: accion,
        resueltoPor: usuario?.codigo ?? 'APP_MOVIL',
        observacion: 'Resuelto desde app movil con accion $accion.',
      );
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Conflicto resuelto correctamente.'),
        backgroundColor: Color(0xFF1D9E75),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _locales
        .where((item) =>
            item.estadoSincronizacion == IncidenteLocal.estadoSyncPendiente ||
            item.estadoSincronizacion == IncidenteLocal.estadoSyncParcial ||
            item.estadoSincronizacion == IncidenteLocal.estadoSyncSincronizando)
        .toList();
    final errores = _locales
        .where((item) =>
            item.estadoSincronizacion == IncidenteLocal.estadoSyncError)
        .toList();
    final conflictosLocales = _locales
        .where((item) =>
            item.estadoSincronizacion == IncidenteLocal.estadoSyncConflicto)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Sincronizacion',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF6B35),
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _resumenHeader(
              pendientes.length,
              errores.length,
              conflictosLocales.length + _conflictosBackend.length,
            ),
            const SizedBox(height: 16),
            _seccionIncidentes('Pendientes', pendientes),
            _seccionIncidentes('Errores', errores),
            _seccionIncidentes('Conflictos locales', conflictosLocales),
            _seccionConflictosBackend(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _sincronizando || _locales.isEmpty ? null : _sincronizar,
              icon: _sincronizando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_sincronizando ? 'Sincronizando...' : 'Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumenHeader(int pendientes, int errores, int conflictos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        _contador('Offline', pendientes, const Color(0xFFFF6B35)),
        _contador('Error', errores, Colors.orange),
        _contador('Conflicto', conflictos, Colors.redAccent),
      ]),
    );
  }

  Widget _contador(String label, int total, Color color) {
    return Expanded(
      child: Column(children: [
        Text(
          '$total',
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ]),
    );
  }

  Widget _seccionIncidentes(String titulo, List<IncidenteLocal> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tituloSeccion(titulo),
      ...items.map(_incidenteCard),
      const SizedBox(height: 12),
    ]);
  }

  Widget _seccionConflictosBackend() {
    if (_cargandoConflictos) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }
    if (_conflictosBackend.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tituloSeccion('Conflictos backend'),
      ..._conflictosBackend.map(_conflictoCard),
      const SizedBox(height: 12),
    ]);
  }

  Widget _tituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        titulo,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _incidenteCard(IncidenteLocal incidente) {
    final esError =
        incidente.estadoSincronizacion == IncidenteLocal.estadoSyncError;
    final esConflicto =
        incidente.estadoSincronizacion == IncidenteLocal.estadoSyncConflicto;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            esConflicto
                ? Icons.rule_folder_outlined
                : esError
                    ? Icons.error_outline
                    : Icons.cloud_upload_outlined,
            color: esConflicto
                ? Colors.redAccent
                : esError
                    ? Colors.orange
                    : const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              incidente.idLocal,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _estadoChip(incidente.estadoSincronizacion),
        ]),
        const SizedBox(height: 10),
        Text(
          incidente.descripcion,
          style: TextStyle(color: Colors.grey[300], fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'Vehiculo ${incidente.vehiculoId} - Categoria ${incidente.categoriaId}'
          '${incidente.idBackend == null ? '' : ' - Backend #${incidente.idBackend}'}',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        if (incidente.idConflicto != null) ...[
          const SizedBox(height: 6),
          Text(
            'Conflicto #${incidente.idConflicto}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        if (incidente.ultimoError != null &&
            incidente.ultimoError!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            incidente.ultimoError!,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ]),
    );
  }

  Widget _conflictoCard(SyncConflicto conflicto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.rule_folder_outlined, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Conflicto #${conflicto.id}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _estadoChip('CONFLICTO'),
        ]),
        const SizedBox(height: 10),
        Text(
          conflicto.tipoConflicto,
          style: TextStyle(color: Colors.grey[300], fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          '${conflicto.idLocalOrigen} - Backend #${conflicto.idIncidenteBackend ?? '-'}',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _accionButton(conflicto, 'CONSERVAR_SERVIDOR'),
          _accionButton(conflicto, 'CREAR_NUEVO'),
          _accionButton(conflicto, 'FUSIONAR_EVIDENCIAS'),
          _accionButton(conflicto, 'DESCARTAR_LOCAL'),
        ]),
      ]),
    );
  }

  Widget _accionButton(SyncConflicto conflicto, String accion) {
    return OutlinedButton(
      onPressed: () => _resolverConflicto(conflicto, accion),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFF6B35),
        side: const BorderSide(color: Color(0xFFFF6B35)),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(accion.replaceAll('_', ' '),
          style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _estadoChip(String estado) {
    final color = switch (estado) {
      IncidenteLocal.estadoSyncSincronizado => const Color(0xFF1D9E75),
      IncidenteLocal.estadoSyncSincronizando => Colors.blueAccent,
      IncidenteLocal.estadoSyncConflicto => Colors.redAccent,
      IncidenteLocal.estadoSyncError => Colors.orange,
      IncidenteLocal.estadoSyncParcial => Colors.amber,
      _ => const Color(0xFFFF6B35),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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
}
