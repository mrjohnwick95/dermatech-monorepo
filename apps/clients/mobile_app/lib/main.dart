import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/environment.dart';

void main() {
  runApp(const DermatechApp());
}

class DermatechApp extends StatelessWidget {
  const DermatechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dermatech QA',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String _statusMessage = "";
  bool _isLoading = false;

  // Lógica de Conexión al Microservicio Auth
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Conectando al servidor...";
    });

    // OJO: 10.0.2.2 es la IP especial para que el Emulador Android vea tu PC (localhost)
    // Si pruebas en web, esto debería ser localhost.
    // IP local si se usa el telefono en fisico como emulador
    final url = Uri.parse('${Environment.apiUrl}/api/v1/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _userController.text,
          'password': _passController.text,
        }),
      );

      if (response.statusCode == 201) { // 201 Created (Éxito)
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        // Aquí guardaríamos el token en el dispositivo
        setState(() {
          _statusMessage = "¡ÉXITO! Token recibido:\n${token.substring(0, 20)}...";
        });
      } else {
        setState(() {
          _statusMessage = "Error ${response.statusCode}: Credenciales inválidas";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error de conexión: Asegúrate que el backend esté corriendo.\n$e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dermatech Auth")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: "Usuario", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("INICIAR SESIÓN"),
                  ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusMessage.startsWith("OK") ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}