import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _codigo = TextEditingController(); // CI
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();

  bool _loading = false;
  bool _verPass = false;
  String _error = '';

  Future<void> _registrar() async {
    if (_codigo.text.trim().isEmpty) {
      setState(() => _error = 'El CI es obligatorio');
      return;
    }

    if (_nombre.text.trim().isEmpty ||
        _apellido.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _telefono.text.trim().isEmpty ||
        _pass.text.trim().isEmpty ||
        _confirmPass.text.trim().isEmpty) {
      setState(() => _error = 'Todos los campos son obligatorios');
      return;
    }

    if (_pass.text != _confirmPass.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await AuthService().registro(
        codigo: _codigo.text.trim(),
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        email: _email.text.trim(),
        contrasena: _pass.text.trim(),
        telefono: _telefono.text.trim(),
      );

      if (!mounted) return;

      if (res['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cuenta creada. Inicia sesión'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        setState(() {
          _error = _normalizarError(res);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _normalizarError(Map<String, dynamic> res) {
    final value = res['error'] ?? res['detail'] ?? 'Error al registrar';

    if (value is String) return value;

    if (value is List) {
      return value.map((e) {
        if (e is Map) {
          final loc = e['loc'];
          final msg = e['msg'];

          if (loc is List && loc.isNotEmpty) {
            return '${loc.last}: $msg';
          }
          if (msg != null) return msg.toString();
        }
        return e.toString();
      }).join('\n');
    }

    if (value is Map) {
      if (value['msg'] != null) return value['msg'].toString();
      return value.toString();
    }

    return value.toString();
  }

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _email.dispose();
    _telefono.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crear Cuenta',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regístrate gratis',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Crea tu cuenta para reportar emergencias',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 28),
            if (_error.isNotEmpty) _alertaError(_error),
            _campo(
              'CI / Carnet de Identidad',
              _codigo,
              Icons.badge_outlined,
              tipo: TextInputType.number,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _campo('Nombre', _nombre, Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campo('Apellido', _apellido, Icons.person_outline),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _campo(
              'Correo electrónico',
              _email,
              Icons.email_outlined,
              tipo: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _campo(
              'Teléfono',
              _telefono,
              Icons.phone_outlined,
              tipo: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _campo(
              'Contraseña',
              _pass,
              Icons.lock_outline,
              oculto: !_verPass,
              sufijo: IconButton(
                icon: Icon(
                  _verPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() => _verPass = !_verPass),
              ),
            ),
            const SizedBox(height: 14),
            _campo(
              'Confirmar contraseña',
              _confirmPass,
              Icons.lock_outline,
              oculto: true,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _registrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Crear Cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController ctrl,
    IconData icon, {
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

  Widget _alertaError(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        msg,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }
}
