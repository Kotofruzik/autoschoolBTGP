import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

class PhonePage extends StatefulWidget {
  final ParseUser user;
  final VoidCallback onPhoneSaved;

  const PhonePage({Key? key, required this.user, required this.onPhoneSaved})
      : super(key: key);

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  bool get _isValidPhone {
    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 11;
  }

  Future<void> _savePhoneNumber() async {
    if (!_isValidPhone) return;

    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _isLoading = true);

    widget.user.set('phone', phoneDigits);
    final response = await widget.user.save();
    if (mounted) setState(() => _isLoading = false);

    if (response.success) {
      widget.onPhoneSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${response.error?.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.lightBlueAccent],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.phone_android,
                        size: 70,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Укажите номер телефона',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'для окончания регистрации',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _phoneController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Номер телефона',
                        hintText: '79203961833',
                        prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: (!_isValidPhone || _isLoading)
                            ? null
                            : _savePhoneNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          disabledBackgroundColor: Colors.white.withOpacity(0.7),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.blue,
                        )
                            : const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}