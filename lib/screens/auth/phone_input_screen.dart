import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'otp_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final String _countryCode = "+91";
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhoneNumber() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.length != 10 || int.tryParse(rawPhone) == null) {
      setState(() => _errorMessage = "Please enter a valid 10-digit mobile number.");
      return;
    }

    final fullPhoneNumber = "$_countryCode$rawPhone";

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    await authService.sendPhoneOtp(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OtpVerificationScreen(
                target: fullPhoneNumber,
                flowType: AuthFlowType.phone,
              ),
            ),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = err;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: const Text('Phone Sign-In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_android_outlined,
                  color: AppTheme.accentAmber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter Mobile Number',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will send a 6-digit one-time password (OTP) via SMS to verify your student account.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Country code + Phone input
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.inkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          _countryCode,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "98765 43210",
                        hintStyle: TextStyle(
                          color: AppTheme.textMuted.withValues(alpha: 0.4),
                          letterSpacing: 1.5,
                        ),
                      ),
                      onSubmitted: (_) => _submitPhoneNumber(),
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitPhoneNumber,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.inkDarker),
                        ),
                      )
                    : const Text('Send SMS Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
