import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'registro_screen.dart';
import 'recuperar_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _verPass = false;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await AuthService().login(
      identificador: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['ok']) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _error = res['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('EmergVial',
                      style: GoogleFonts.spaceMono(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Asistencia vehicular 24/7',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 48),
              Text('Iniciar Sesión',
                  style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text('Accede a tu cuenta',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              const SizedBox(height: 28),
              if (_error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13))),
                  ]),
                ),
              _campo('Correo electrónico', _emailCtrl,
                  icon: Icons.email_outlined, tipo: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _campo('Contraseña', _passCtrl,
                  icon: Icons.lock_outline,
                  oculto: !_verPass,
                  sufijo: IconButton(
                    icon: Icon(
                        _verPass ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[500],
                        size: 20),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  )),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecuperarPasswordScreen())),
                  child: const Text('¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Iniciar Sesión',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('¿No tienes cuenta? ',
                    style: TextStyle(color: Colors.grey[500])),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegistroScreen())),
                  child: const Text('Regístrate',
                      style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController ctrl, {
    required IconData icon,
    TextInputType tipo = TextInputType.text,
    bool oculto = false,
    Widget? sufijo,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: oculto,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        suffixIcon: sufijo,
      ),
    );
  }
}
