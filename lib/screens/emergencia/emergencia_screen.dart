import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tallermovil/services/evidencia_service.dart';
import 'dart:io';
import '../../models/vehiculo.dart';
import '../../models/usuario.dart';
import '../../services/vehiculo_service.dart';
import '../../services/incidente_service.dart';
import '../../services/auth_service.dart';

class EmergenciaScreen extends StatefulWidget {
  const EmergenciaScreen({super.key});
  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  int _paso = 0; // 0=tipo, 1=ubicacion, 2=detalles, 3=confirmado

  int? _categoriaSeleccionada;
  String _descripcion = '';
  Position? _posicion;
  List<File> _fotos = [];
  File? _audioFile;
  String _transcripcionAudio = '';
  Vehiculo? _vehiculoSeleccionado;
  List<Vehiculo> _vehiculos = [];
  Usuario? _usuario;
  bool _loadingUbicacion = false;
  bool _enviando = false;
  int? _incidenteCreado;

  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

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

  Future<void> _inicializar() async {
    _usuario = await AuthService().getUsuarioActual();
    if (_usuario != null) {
      final lista = await VehiculoService().listarPorUsuario(_usuario!.codigo);
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

  Future<void> _enviarReporte() async {
    if (_vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona un vehículo'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _enviando = true);

    // PASO 1: Crear el incidente
    final resIncidente = await IncidenteService().crear(
      descripcion: _descCtrl.text.isEmpty
          ? _categorias
              .firstWhere((c) => c['id'] == _categoriaSeleccionada)['nombre']
          : _descCtrl.text,
      latitud: _posicion?.latitude ?? -17.7833,
      longitud: _posicion?.longitude ?? -63.1821,
      idVehiculo: _vehiculoSeleccionado!.codigo,
      idCategoria: _categoriaSeleccionada!,
      codigoUsuario: _usuario!.codigo,
    );

    if (!resIncidente['ok']) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resIncidente['error']), backgroundColor: Colors.red));
      return;
    }

    final idIncidente = resIncidente['data']['codigo'];
    final evidenciaSvc = EvidenciaService();

    // PASO 2: Subir fotos (CU-11)
    for (final foto in _fotos) {
      await evidenciaSvc.subirImagen(idIncidente: idIncidente, imagen: foto);
    }

    // PASO 3: Subir audio si existe (CU-11 + CU-14)
    if (_audioFile != null) {
      final resAudio = await evidenciaSvc.subirAudio(
          idIncidente: idIncidente, audio: _audioFile!);
      if (resAudio['ok'] && resAudio['transcripcion']?.isNotEmpty == true) {
        setState(() => _transcripcionAudio = resAudio['transcripcion']);
      }
    }

    // PASO 4: Subir descripción de texto si hay (CU-11)
    if (_descCtrl.text.isNotEmpty) {
      await evidenciaSvc.subirTexto(
          idIncidente: idIncidente, descripcion: _descCtrl.text);
    }

    // PASO 5: Procesar con IA automáticamente (CU-12 + CU-13)
    await evidenciaSvc.procesarConIA(idIncidente);

    setState(() {
      _enviando = false;
      _incidenteCreado = idIncidente;
      _paso = 3;
    });
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
          ]),
        ),
      ),
      _botonSiguiente(
        _enviando ? 'Enviando...' : '🚨 Enviar Reporte de Emergencia',
        _enviando ? null : _enviarReporte,
        color: const Color(0xFFDC2626),
      ),
    ]);
  }

  // PASO 3: Confirmado
  Widget _pantallaConfirmado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle,
                size: 60, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 24),
          Text('¡Reporte Enviado!',
              style: GoogleFonts.outfit(
                  fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
              'Tu reporte #$_incidenteCreado fue recibido.\nUn técnico será asignado pronto.',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07))),
            child: Column(children: [
              _estadoItem(
                  Icons.check_circle, '4CAF50', 'Reporte recibido', true),
              _estadoItem(Icons.access_time, '8B949E',
                  'Buscando taller cercano', false),
              _estadoItem(
                  Icons.person_outline, '8B949E', 'Técnico en camino', false),
            ]),
          ),
          const SizedBox(height: 32),
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
