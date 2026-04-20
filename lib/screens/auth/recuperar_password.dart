import 'package:flutter/material.dart';
import "package:google_fonts/google_fonts.dart";
import '../../services/auth_service.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});
  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _enviado = false;
  String _error = '';

  Future<void> _enviar() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await AuthService().recuperarPassword(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['ok'])
        _enviado = true;
      else
        _error = res['error'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recuperar Contraseña',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: _enviado ? _pantallaExito() : _formulario(),
      ),
    );
  }

  Widget _formulario() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child:
              const Icon(Icons.lock_reset, size: 40, color: Color(0xFFFF6B35)),
        ),
      ),
      const SizedBox(height: 28),
      Text('Olvidé mi contraseña',
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
          'Ingresa tu email y te enviaremos instrucciones para restablecer tu contraseña',
          style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
      const SizedBox(height: 32),
      if (_error.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Correo electrónico',
          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey, size: 20),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _loading ? null : _enviar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Enviar instrucciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  Widget _pantallaExito() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 48, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 24),
        Text('¡Correo Enviado!',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Revisa tu bandeja de entrada',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver al login',
              style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
