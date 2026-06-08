import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tallermovil/services/evidencia_service.dart';
import '../../models/linea_tiempo.dart';
import '../../models/vehiculo.dart';
import '../../models/usuario.dart';
import '../../services/vehiculo_service.dart';
import '../../services/incidente_service.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../chat/chat_incidente_screen.dart';
import '../cotizaciones/cotizaciones_express_screen.dart';
import '../evaluaciones/evaluar_servicio_screen.dart';
import '../incidentes/linea_tiempo_screen.dart';
import '../pagos/pago_servicio_screen.dart';
import '../tracking/tracking_en_vivo_screen.dart';
import '../validacion/codigo_arribo_screen.dart';

class EmergenciaScreen extends StatefulWidget {
  const EmergenciaScreen({super.key});
  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  int _paso = 0; // 0=tipo, 1=ubicacion, 2=detalles, 3=confirmado

  int? _categoriaSeleccionada;
  Position? _posicion;
  List<File> _fotos = [];
  List<File> _audios = [];
  List<String> _transcripcionesAudio = [];
  Vehiculo? _vehiculoSeleccionado;
  List<Vehiculo> _vehiculos = [];
  Usuario? _usuario;
  bool _loadingUbicacion = false;
  bool _enviando = false;
  bool _cotizacionExpress = false;
  bool _actualizandoEstado = false;
  bool _reporteOffline = false;
  int? _incidenteCreado;
  String? _incidenteOfflineCreado;
  Timer? _estadoTimer;
  LineaTiempoServicio? _lineaTiempo;
  String? _errorEstado;

  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  static const MethodChannel _audioPickerChannel =
      MethodChannel('tallermovil/audio_picker');

  final List<Map<String, dynamic>> _categorias = [
    {
      'id': 1,
      'emoji': '🔋',
      'nombre': 'Batería',
      'desc': 'No enciende, sin energía'
    },
    {
      'id': 2,
      'emoji': '🛞',
      'nombre': 'Llanta',
      'desc': 'Pinchazo, llanta baja'
    },
    {
      'id': 3,
      'emoji': '⚙️',
      'nombre': 'Motor',
      'desc': 'Falla mecánica, ruido'
    },
    {'id': 4, 'emoji': '🚗', 'nombre': 'Choque', 'desc': 'Accidente, colisión'},
    {'id': 5, 'emoji': '⛽', 'nombre': 'Combustible', 'desc': 'Sin gasolina'},
    {
      'id': 6,
      'emoji': '🔑',
      'nombre': 'Cerrajería',
      'desc': 'Llave adentro, perdida'
    },
    {
      'id': 7,
      'emoji': '🌡️',
      'nombre': 'Temperatura',
      'desc': 'Motor caliente'
    },
    {'id': 8, 'emoji': '❓', 'nombre': 'Otro', 'desc': 'Otro tipo de problema'},
  ];

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _estadoTimer?.cancel();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    _usuario = await AuthService().getUsuarioActual();
    if (_usuario != null) {
      final lista = await VehiculoService().listarMisVehiculos();
      setState(() => _vehiculos = lista);
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _loadingUbicacion = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _loadingUbicacion = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _posicion = pos;
        _loadingUbicacion = false;
      });
    } catch (e) {
      setState(() => _loadingUbicacion = false);
    }
  }

  Future<void> _agregarFoto() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2))),
        ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFFFF6B35)),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFFFF6B35)),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
        const SizedBox(height: 16),
      ]),
    );
    if (fuente == null) return;
    final img = await _picker.pickImage(source: fuente, imageQuality: 70);
    if (img != null) setState(() => _fotos.add(File(img.path)));
  }

  // CU-14: Adjuntar audio como evidencia para que el backend lo transcriba.
  Future<void> _agregarAudio() async {
    try {
      final result =
          await _audioPickerChannel.invokeMethod<Map<dynamic, dynamic>>(
        'pickAudio',
      );
      if (result == null) return;

      final path = result['path']?.toString();
      if (path == null || path.isEmpty) return;

      setState(() => _audios.add(File(path)));
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message ?? 'No se pudo seleccionar el audio'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _nombreArchivo(File archivo) {
    return archivo.path.split(Platform.pathSeparator).last;
  }

  String _descripcionReporte() {
    return _descCtrl.text.trim().isEmpty
        ? _categorias
            .firstWhere((c) => c['id'] == _categoriaSeleccionada)['nombre']
            .toString()
        : _descCtrl.text.trim();
  }

  Future<void> _guardarReporteOffline(String descripcion) async {
    // CU-OFF-01: Registrar incidente en modo offline local cuando no hay red.
    // CU-OFF-02: Guardar fotos, audios y texto para sincronizarlos despues.
    final idLocal = await OfflineSyncService().guardarIncidenteLocal(
      descripcion: descripcion,
      latitud: _posicion?.latitude ?? -17.7833,
      longitud: _posicion?.longitude ?? -63.1821,
      idVehiculo: _vehiculoSeleccionado!.codigo,
      idCategoria: _categoriaSeleccionada!,
      codigoUsuario: _usuario!.codigo,
      cotizacionExpress: _cotizacionExpress,
      imagenes: _fotos,
      audios: _audios,
    );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _reporteOffline = true;
      _incidenteCreado = null;
      _incidenteOfflineCreado = idLocal;
      _paso = 3;
    });
  }

  Future<void> _enviarReporte() async {
    if (_vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona un vehículo'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _enviando = true);
    final descripcion = _descripcionReporte();

    // CU-OFF-03: Si no hay internet, no se pierde el reporte: queda pendiente.
    if (!await OfflineSyncService().hayConexion()) {
      await _guardarReporteOffline(descripcion);
      return;
    }

    // PASO 1: Crear el incidente
    late final Map<String, dynamic> resIncidente;
    try {
      resIncidente = await IncidenteService().crear(
        descripcion: descripcion,
        latitud: _posicion?.latitude ?? -17.7833,
        longitud: _posicion?.longitude ?? -63.1821,
        idVehiculo: _vehiculoSeleccionado!.codigo,
        idCategoria: _categoriaSeleccionada!,
        codigoUsuario: _usuario!.codigo,
        cotizacionExpress: _cotizacionExpress,
      );
    } on SocketException {
      await _guardarReporteOffline(descripcion);
      return;
    } catch (e) {
      if (!await OfflineSyncService().hayConexion()) {
        await _guardarReporteOffline(descripcion);
        return;
      }
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al reportar: $e'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (!resIncidente['ok']) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resIncidente['error']), backgroundColor: Colors.red));
      return;
    }

    final idIncidente = int.tryParse(
          resIncidente['data']?['codigo']?.toString() ?? '',
        ) ??
        0;
    if (idIncidente <= 0) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El backend no devolvio un incidente valido.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_cotizacionExpress) {
      if (!mounted) return;
      final fotos = List<File>.from(_fotos);
      final audios = List<File>.from(_audios);
      setState(() => _enviando = false);
      unawaited(_procesarEvidenciasEnSegundoPlano(
        idIncidente,
        fotos: fotos,
        audios: audios,
        descripcion: descripcion,
      ));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CotizacionesExpressScreen(
            idIncidente: idIncidente,
          ),
        ),
      );
      return;
    }

    final evidenciaSvc = EvidenciaService();

    // PASO 2: Subir evidencias juntas: imagenes, audios y texto.
    if (_fotos.isNotEmpty || _audios.isNotEmpty || descripcion.isNotEmpty) {
      final resMultimedia = await evidenciaSvc.subirMultimedia(
        idIncidente: idIncidente,
        imagenes: _fotos,
        audios: _audios,
        texto: descripcion,
      );
      if (resMultimedia['ok'] == true) {
        setState(() {
          _transcripcionesAudio =
              List<String>.from(resMultimedia['transcripciones_audio'] ?? []);
        });
      }
    }

    // PASO 4: Subir descripción de texto si hay (CU-11)

    // PASO 5: Procesar con IA automáticamente (CU-12 + CU-13)
    await evidenciaSvc.procesarConIA(idIncidente);

    setState(() {
      _enviando = false;
      _incidenteCreado = idIncidente;
      _paso = 3;
    });
    _iniciarSeguimientoEstado(idIncidente);
  }

  Future<void> _procesarEvidenciasEnSegundoPlano(
    int idIncidente, {
    required List<File> fotos,
    required List<File> audios,
    required String descripcion,
  }) async {
    final evidenciaSvc = EvidenciaService();

    try {
      if (fotos.isNotEmpty || audios.isNotEmpty || descripcion.isNotEmpty) {
        await evidenciaSvc.subirMultimedia(
          idIncidente: idIncidente,
          imagenes: fotos,
          audios: audios,
          texto: descripcion,
        );
      }

      await evidenciaSvc.procesarConIA(idIncidente);
    } catch (e) {
      debugPrint('Error procesando evidencias del incidente: $e');
    }
  }

  void _iniciarSeguimientoEstado(int idIncidente) {
    _estadoTimer?.cancel();
    _cargarEstadoIncidente(idIncidente);
    _estadoTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _cargarEstadoIncidente(idIncidente, silencioso: true),
    );
  }

  Future<void> _cargarEstadoIncidente(
    int idIncidente, {
    bool silencioso = false,
  }) async {
    if (_actualizandoEstado) return;

    if (mounted) {
      setState(() {
        _actualizandoEstado = true;
        if (!silencioso) _errorEstado = null;
      });
    }
    try {
      final linea = await IncidenteService().consultarLineaTiempo(idIncidente);
      if (!mounted) return;
      setState(() {
        _actualizandoEstado = false;
        _lineaTiempo = linea;
        _errorEstado = null;
      });
      if (_servicioFinalizado) _estadoTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actualizandoEstado = false;
        _errorEstado = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        title: Text('Reportar Emergencia',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white)),
        leading: _paso > 0 && _paso < 3
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                onPressed: () => setState(() => _paso--))
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
      ),
      body: [
        _pantallaTipo(),
        _pantallaUbicacion(),
        _pantallaDetalles(),
        _pantallaConfirmado(),
      ][_paso],
    );
  }

  // PASO 0: Tipo de emergencia
  Widget _pantallaTipo() {
    return Column(children: [
      _barraProgreso(1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Qué tipo de problema tienes?',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Selecciona la categoría de tu emergencia',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4),
              itemCount: _categorias.length,
              itemBuilder: (_, i) {
                final c = _categorias[i];
                final sel = _categoriaSeleccionada == c['id'];
                return GestureDetector(
                  onTap: () => setState(() => _categoriaSeleccionada = c['id']),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFDC2626).withOpacity(0.15)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFFDC2626)
                              : Colors.white.withOpacity(0.07),
                          width: sel ? 2 : 1),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['emoji'],
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 8),
                          Text(c['nombre'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(c['desc'],
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
      _botonSiguiente(
        'Continuar',
        _categoriaSeleccionada != null ? () => setState(() => _paso = 1) : null,
      ),
    ]);
  }

  // PASO 1: Ubicación GPS
  Widget _pantallaUbicacion() {
    return Column(children: [
      _barraProgreso(2),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    _posicion != null
                        ? Icons.location_on
                        : Icons.location_searching,
                    size: 56,
                    color: _posicion != null
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFDC2626)),
              ),
              const SizedBox(height: 28),
              Text(
                  _posicion != null
                      ? '📍 Ubicación capturada'
                      : 'Capturar mi ubicación',
                  style: GoogleFonts.outfit(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                  _posicion != null
                      ? 'Lat: ${_posicion!.latitude.toStringAsFixed(5)}\nLng: ${_posicion!.longitude.toStringAsFixed(5)}'
                      : 'Necesitamos tu ubicación GPS para enviar ayuda al lugar exacto',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),
              if (_posicion == null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loadingUbicacion ? null : _obtenerUbicacion,
                    icon: _loadingUbicacion
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.gps_fixed),
                    label: Text(_loadingUbicacion
                        ? 'Obteniendo ubicación...'
                        : 'Activar GPS'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              if (_posicion != null)
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3))),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50), size: 20),
                          SizedBox(width: 8),
                          Text('Ubicación lista para el reporte',
                              style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.bold)),
                        ])),
            ],
          ),
        ),
      ),
      _botonSiguiente(
        _posicion != null ? 'Continuar' : 'Saltar (no recomendado)',
        () => setState(() => _paso = 2),
      ),
    ]);
  }

  // PASO 2: Detalles y fotos
  Widget _pantallaDetalles() {
    return Column(children: [
      _barraProgreso(3),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Detalles del problema',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Selección de vehículo
            Text('Vehículo afectado',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_vehiculos.isEmpty)
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('No tienes vehículos registrados',
                      style: TextStyle(color: Colors.orange, fontSize: 13))),
            ...(_vehiculos.map((v) => _opcionVehiculo(v))),
            const SizedBox(height: 20),

            Text('Modo de atencion',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: Text('Automatica'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.request_quote_outlined),
                  label: Text('Cotizaciones'),
                ),
              ],
              selected: {_cotizacionExpress},
              onSelectionChanged: (seleccion) {
                setState(() => _cotizacionExpress = seleccion.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFFFF6B35).withOpacity(0.18);
                  }
                  return const Color(0xFF161B22);
                }),
                foregroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFFFF6B35);
                  }
                  return Colors.grey[400];
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cotizacionExpress
                  ? 'Recibiras ofertas de talleres cercanos y elegiras una.'
                  : 'El sistema asignara automaticamente un taller disponible.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Descripción
            Text('Descripción (opcional)',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: 'Ej: El auto hace un ruido extraño al arrancar...',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 20),

            // Fotos
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Fotos del problema',
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _agregarFoto,
                icon: const Icon(Icons.add_a_photo,
                    size: 18, color: Color(0xFFFF6B35)),
                label: const Text('Agregar',
                    style: TextStyle(color: Color(0xFFFF6B35))),
              ),
            ]),
            if (_fotos.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotos.length,
                  itemBuilder: (_, i) => Stack(children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                              image: FileImage(_fotos[i]), fit: BoxFit.cover)),
                    ),
                    Positioned(
                        top: 4,
                        right: 14,
                        child: GestureDetector(
                          onTap: () => setState(() => _fotos.removeAt(i)),
                          child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white)),
                        )),
                  ]),
                ),
              ),
            if (_fotos.isEmpty)
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07),
                        style: BorderStyle.solid)),
                child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.grey[600], size: 28),
                      const SizedBox(height: 4),
                      Text('Toca "Agregar" para subir fotos',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ])),
              ),
            const SizedBox(height: 20),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Audio para transcribir',
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _agregarAudio,
                icon: const Icon(Icons.mic, size: 18, color: Color(0xFFFF6B35)),
                label: const Text('Adjuntar',
                    style: TextStyle(color: Color(0xFFFF6B35))),
              ),
            ]),
            if (_audios.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.07))),
                child: Row(children: [
                  Icon(Icons.graphic_eq, color: Colors.grey[600], size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Adjunta un audio y se transcribira al enviar el reporte',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ]),
              ),
            if (_audios.isNotEmpty)
              Column(
                children: _audios.asMap().entries.map((entry) {
                  final index = entry.key;
                  final audio = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07))),
                    child: Row(children: [
                      const Icon(Icons.audio_file,
                          color: Color(0xFFFF6B35), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _nombreArchivo(audio),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _audios.removeAt(index)),
                        icon: const Icon(Icons.close,
                            color: Colors.redAccent, size: 20),
                      ),
                    ]),
                  );
                }).toList(),
              ),
          ]),
        ),
      ),
      _botonSiguiente(
        _enviando
            ? 'Enviando...'
            : _cotizacionExpress
                ? 'Solicitar cotizaciones'
                : 'Enviar Reporte de Emergencia',
        _enviando ? null : _enviarReporte,
        color: const Color(0xFFDC2626),
      ),
    ]);
  }

  // PASO 3: Confirmado
  Widget _pantallaConfirmado() {
    final idIncidente = _incidenteCreado;
    final tallerAsignado = _tallerAsignado;
    final tecnicoEnCamino = _tecnicoEnCamino;
    final servicioFinalizado = _servicioFinalizado;

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: idIncidente == null
          ? () async {}
          : () => _cargarEstadoIncidente(idIncidente),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Column(children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: (_reporteOffline ? Colors.orange : Colors.green)
                    .withOpacity(0.12),
                shape: BoxShape.circle),
            child: Icon(
              _reporteOffline ? Icons.cloud_off_outlined : Icons.check_circle,
              size: 60,
              color: _reporteOffline ? Colors.orange : const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 24),
          Text(_reporteOffline ? 'Reporte guardado offline' : 'Reporte enviado',
              style: GoogleFonts.outfit(
                  fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
              _reporteOffline
                  ? 'Tu reporte $_incidenteOfflineCreado quedo pendiente de sincronizacion.\nCuando vuelva internet podras enviarlo al backend.'
                  : 'Tu reporte #$_incidenteCreado fue recibido.\nUn tecnico sera asignado pronto.',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _reporteOffline ? _offlinePendienteChip() : _estadoEnVivoChip(),
          if (_transcripcionesAudio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.07))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.text_snippet_outlined,
                          color: Color(0xFFFF6B35), size: 18),
                      SizedBox(width: 8),
                      Text('Transcripcion del audio',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      _transcripcionesAudio.join('\n\n'),
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 13, height: 1.4),
                    ),
                  ]),
            ),
          ],
          const SizedBox(height: 24),
          if (!_reporteOffline)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.07))),
              child: Column(children: [
                _estadoItem(
                    Icons.check_circle, '4CAF50', 'Reporte recibido', true),
                _estadoItem(
                  tallerAsignado
                      ? Icons.home_repair_service_outlined
                      : Icons.access_time,
                  tallerAsignado ? '4CAF50' : '8B949E',
                  tallerAsignado
                      ? 'Taller asignado'
                      : 'Buscando taller cercano',
                  tallerAsignado,
                ),
                if (tecnicoEnCamino)
                  _estadoItem(Icons.local_shipping_outlined, '4CAF50',
                      'Tecnico en camino', true),
                if (servicioFinalizado)
                  _estadoItem(Icons.check_circle_outline, '4CAF50',
                      'Servicio finalizado', true),
                if (!tecnicoEnCamino)
                  _estadoItem(Icons.person_outline, '8B949E',
                      'Técnico en camino', false),
              ]),
            ),
          if (_errorEstado != null) ...[
            const SizedBox(height: 12),
            _avisoEstado(_errorEstado!),
          ],
          const SizedBox(height: 24),
          if (_incidenteCreado != null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EvaluarServicioScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate_outlined),
                label: const Text('Evaluar servicio'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB020),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PagoServicioScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Pago y comprobante'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatIncidenteScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Abrir chat con tecnico'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CodigoArriboScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Ver PIN o QR de arribo'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackingEnVivoScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver ubicacion en vivo'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LineaTiempoScreen(
                        idIncidente: _incidenteCreado!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.timeline),
                label: const Text('Ver linea de tiempo'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('Volver al inicio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _estadoEnVivoChip() {
    final estado = _lineaTiempo?.estadoActual ?? 'Actualizando estado';
    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_actualizandoEstado)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: Color(0xFFFF6B35),
              strokeWidth: 2,
            ),
          )
        else
          const Icon(Icons.sync, size: 15, color: Color(0xFF1D9E75)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            estado,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _offlinePendienteChip() {
    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orange.withOpacity(0.28)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_upload_outlined, size: 15, color: Colors.orange),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Pendiente de sincronizacion',
            style: TextStyle(color: Colors.orange, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _avisoEstado(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(color: Colors.orange, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  bool get _tallerAsignado {
    return _contieneEstado(['taller', 'asign']);
  }

  bool get _tecnicoEnCamino {
    return _contieneEstado(['tecnico', 'camino']) ||
        _contieneEstado(['desplaz', 'ruta']);
  }

  bool get _servicioFinalizado {
    return _contieneEstado(['final', 'cerr', 'complet']);
  }

  bool _contieneEstado(List<String> palabras) {
    final linea = _lineaTiempo;
    if (linea == null) return false;

    final textos = <String>[linea.estadoActual.toLowerCase()];
    for (final evento in linea.eventos) {
      textos.add(evento.codigo.toLowerCase());
      textos.add(evento.titulo.toLowerCase());
      textos.add(evento.descripcion.toLowerCase());
      textos.add(evento.estado.toLowerCase());
    }

    return textos.any(
      (texto) => palabras.any((palabra) => texto.contains(palabra)),
    );
  }

  Widget _estadoItem(
      IconData icon, String colorHex, String texto, bool activo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: Color(int.parse('0xFF$colorHex'))),
        const SizedBox(width: 12),
        Text(texto,
            style: TextStyle(
                color: activo ? Colors.white : Colors.grey[500],
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
      ]),
    );
  }

  Widget _opcionVehiculo(Vehiculo v) {
    final sel = _vehiculoSeleccionado?.codigo == v.codigo;
    return GestureDetector(
      onTap: () => setState(() => _vehiculoSeleccionado = v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: sel
                ? const Color(0xFFFF6B35).withOpacity(0.1)
                : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel
                    ? const Color(0xFFFF6B35)
                    : Colors.white.withOpacity(0.07),
                width: sel ? 2 : 1)),
        child: Row(children: [
          Icon(Icons.directions_car,
              color: sel ? const Color(0xFFFF6B35) : Colors.grey[500],
              size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text('${v.marca} ${v.modelo} — ${v.placa}',
                  style: TextStyle(
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? Colors.white : Colors.grey[400]))),
          if (sel)
            const Icon(Icons.check_circle, color: Color(0xFFFF6B35), size: 20),
        ]),
      ),
    );
  }

  Widget _barraProgreso(int pasoActual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
          children: List.generate(3, (i) {
        final completado = i < pasoActual;
        final actual = i == pasoActual - 1;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                    color: completado || actual
                        ? const Color(0xFFDC2626)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ]),
        );
      })),
    );
  }

  Widget _botonSiguiente(String texto, VoidCallback? onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: color ?? const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.grey.withOpacity(0.2)),
          child: Text(texto,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
