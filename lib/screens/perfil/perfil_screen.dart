import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Usuario? _usuario;
  bool _editando = false;
  bool _loading = false;
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _telefono = TextEditingController();
  final _passActual = TextEditingController();
  final _passNueva = TextEditingController();
  final _passConfirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final u = await AuthService().getUsuarioActual();
    setState(() {
      _usuario = u;
      _nombre.text = u?.nombre ?? '';
      _apellido.text = u?.apellido ?? '';
      _telefono.text = u?.telefono ?? '';
    });
  }

  Future<void> _guardar() async {
    setState(() => _loading = true);
    final res = await AuthService().actualizarPerfil(
      codigo: _usuario!.codigo,
      datos: {
        'nombre': _nombre.text.trim(),
        'apellido': _apellido.text.trim(),
        'telefono': _telefono.text.trim(),
      },
    );
    setState(() {
      _loading = false;
      _editando = false;
    });
    if (res['ok']) {
      _cargar();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Perfil actualizado'),
            backgroundColor: Color(0xFF4CAF50)));
    }
  }

  Future<void> _cambiarPassword() async {
    if (_passNueva.text != _passConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    final res = await AuthService().cambiarPassword(
      email: _usuario!.email,
      nuevaContrasena: _passNueva.text,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['ok'] ? '✅ Contraseña actualizada' : res['error']),
        backgroundColor: res['ok'] ? const Color(0xFF4CAF50) : Colors.red));
    if (res['ok']) {
      _passActual.clear();
      _passNueva.clear();
      _passConfirm.clear();
      Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Perfil',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (!_editando)
            IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B35)),
                onPressed: () => setState(() => _editando = true)),
          if (_editando)
            TextButton(
                onPressed: _loading ? null : _guardar,
                child: Text(_loading ? 'Guardando...' : 'Guardar',
                    style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // AVATAR
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFFF6B35),
            child: Text(_usuario?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text('${_usuario?.nombre} ${_usuario?.apellido}',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(_usuario?.email ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 32),

          // DATOS PERSONALES
          _seccion('Datos Personales', [
            _campoEditable('Nombre', _nombre, Icons.person_outline, _editando),
            _campoEditable(
                'Apellido', _apellido, Icons.person_outline, _editando),
            _campoEditable(
                'Teléfono', _telefono, Icons.phone_outlined, _editando,
                tipo: TextInputType.phone),
            _campoInfo('Correo', _usuario?.email ?? '', Icons.email_outlined),
          ]),
          const SizedBox(height: 20),

          // SEGURIDAD
          _seccion('Seguridad', [
            _botonAccion(
              icono: Icons.lock_outline,
              label: 'Cambiar contraseña',
              color: const Color(0xFFFF6B35),
              onTap: () => _mostrarCambiarPassword(),
            ),
          ]),
          const SizedBox(height: 20),

          // CERRAR SESIÓN
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Cerrar Sesión',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400])),
        const SizedBox(height: 14),
        ...hijos,
      ]),
    );
  }

  Widget _campoEditable(
      String label, TextEditingController ctrl, IconData icon, bool editable,
      {TextInputType tipo = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        enabled: editable,
        keyboardType: tipo,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          fillColor: editable
              ? const Color(0xFF0F3460)
              : Colors.white.withOpacity(0.03),
        ),
      ),
    );
  }

  Widget _campoInfo(String label, String valor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: Colors.grey[500], size: 18),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text(valor, style: const TextStyle(fontSize: 14)),
        ]),
      ]),
    );
  }

  Widget _botonAccion({
    required IconData icono,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: color, size: 22),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _mostrarCambiarPassword() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Cambiar Contraseña',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
              controller: _passNueva,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nueva contraseña')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _passConfirm,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration:
                  const InputDecoration(labelText: 'Confirmar contraseña')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _cambiarPassword,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Actualizar contraseña',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}
