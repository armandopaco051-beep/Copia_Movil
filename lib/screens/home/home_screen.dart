import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../perfil/perfil_screen.dart';
import '../vehiculos/vehiculos_screen.dart';
import '../emergencia/emergencia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;
  Usuario? _usuario;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthService().getUsuarioActual();
    setState(() => _usuario = u);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(
          usuario: _usuario,
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
  final VoidCallback onEmergencia;
  const _HomeTab({this.usuario, required this.onEmergencia});

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
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFF6B35),
              child: Text(usuario?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
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
