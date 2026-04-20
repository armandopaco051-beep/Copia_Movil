import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/comunication_service.dart';

void main() {
  runApp(const EmergVialApp());
}

class EmergVialApp extends StatelessWidget {
  const EmergVialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmergVial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFF1D9E75),
          surface: Color(0xFF161B22),
          error: Color(0xFFF44336),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F3460),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF6B35)),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8B949E)),
          hintStyle: const TextStyle(color: Color(0xFF8B949E)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    await Future.delayed(const Duration(seconds: 2));

    // Validar conexión con el backend
    final communicationService = CommunicationService();
    final conexionResult = await communicationService.get('/health');

    if (conexionResult['ok']) {
      print('✅ Conexión exitosa con el backend');
    } else {
      print('❌ Error de conexión: ${conexionResult['error']}');
      // Mostrar diálogo de error y continuar
      if (!mounted) return;
      _mostrarErrorConexion();
      return;
    }

    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  void _mostrarErrorConexion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Error de Conexión'),
        content: const Text(
          'No se pudo conectar con el servidor. Verifica tu conexión a internet o contacta al administrador.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _verificarSesion(); // Reintentar
            },
            child: const Text('Reintentar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Continuar sin conexión
              final loggedIn = await AuthService().isLoggedIn();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      loggedIn ? const HomeScreen() : const LoginScreen(),
                ),
              );
            },
            child: const Text('Continuar sin conexión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  size: 52, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('EmergVial',
                style: GoogleFonts.spaceMono(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),
            const SizedBox(height: 8),
            Text('Asistencia Vehicular Inteligente',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
                color: Color(0xFFFF6B35), strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
