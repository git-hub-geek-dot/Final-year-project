import 'package:flutter/material.dart';

class UpdateEmailScreen extends StatefulWidget {
  const UpdateEmailScreen({super.key});

  @override
  State<UpdateEmailScreen> createState() => _UpdateEmailScreenState();
}

class _UpdateEmailScreenState extends State<UpdateEmailScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentEmailController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 🔧 Simulate API / Firebase call
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Verification email sent to new address"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Email"),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentEmailController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Current Email",
                  hintText: "user@example.com",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter new email address";
                  }
                  if (!value.contains("@")) {
                    return "Enter a valid email";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "New Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter your password" : null,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text(
                          "Update Email",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
