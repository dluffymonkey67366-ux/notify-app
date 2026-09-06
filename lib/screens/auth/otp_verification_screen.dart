import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String target; // phone number or email
  final AuthFlowType flowType;

  const OtpVerificationScreen({
    super.key,
    required this.target,
    required this.flowType,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = "Please enter the complete 6-digit OTP code.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    bool success = false;
    if (widget.flowType == AuthFlowType.phone) {
      success = await authService.verifyPhoneOtp(
        smsCode: code,
        onError: (err) => setState(() => _errorMessage = err),
      );
    } else {
      success = await authService.verifyGoogleEmailOtp(
        otpCode: code,
        onError: (err) => setState(() => _errorMessage = err),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.resendOtp(
      onSuccess: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.accentTeal),
          );
          _startCountdown();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _errorMessage = err);
        }
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.flowType == AuthFlowType.phone;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () async {
            await Provider.of<AuthService>(context, listen: false).cancelPendingAuth();
            if (context.mounted) Navigator.of(context).pop();
          },
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
                  color: AppTheme.accentAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPhone ? Icons.sms_outlined : Icons.mark_email_read_outlined,
                  color: AppTheme.accentAmber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isPhone ? 'Verify Phone Number' : 'Verify Google Email',
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(
                      text: isPhone
                          ? 'Enter the 6-digit SMS verification code sent to '
                          : 'Enter the 6-digit security code dispatched to your Google account ',
                    ),
                    TextSpan(
                      text: widget.target,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // OTP Input Field
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "••••••",
                  hintStyle: TextStyle(
                    color: AppTheme.textMuted.withOpacity(0.4),
                    letterSpacing: 12,
                  ),
                ),
                onChanged: (val) {
                  if (val.length == 6) {
                    _verifyOtp();
                  }
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
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

              // Verify button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.inkDarker),
                        ),
                      )
                    : const Text('Verify & Open Notify'),
              ),

              const SizedBox(height: 24),

              // Resend action
              Center(
                child: TextButton(
                  onPressed: _resendCountdown == 0 && !_isLoading ? _resendCode : null,
                  child: Text(
                    _resendCountdown > 0
                        ? "Resend code in ${_resendCountdown}s"
                        : "Didn't receive code? Resend",
                    style: TextStyle(
                      color: _resendCountdown > 0 ? AppTheme.textMuted : AppTheme.accentAmber,
                      fontWeight: FontWeight.w600,
                    ),
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
