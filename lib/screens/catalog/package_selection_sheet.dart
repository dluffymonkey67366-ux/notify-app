import 'package:flutter/material.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';

/// Interactive package selection and duration picker widget.
///
/// Strict Requirements Met:
/// 1. Displays packages covering content (Part, Lesson, Subject, or Bundle).
/// 2. Selecting a package shows ONLY the durations that package actually offers
///    (subset of monthly/3mo/6mo/1yr) with that package's own price for each.
/// 3. Durations not offered by the package are GENUINELY HIDDEN (excluded from widget tree),
///    not just visually disabled.
/// 4. "Purchase" button calls the stubbed `grantAccess(packageId, planDuration)` function.
class PackageSelectionSheet extends StatefulWidget {
  final List<Package> packages;
  final String? initialSelectedPackageId;
  final VoidCallback? onPurchaseSuccess;

  const PackageSelectionSheet({
    super.key,
    required this.packages,
    this.initialSelectedPackageId,
    this.onPurchaseSuccess,
  });

  @override
  State<PackageSelectionSheet> createState() => _PackageSelectionSheetState();
}

class _PackageSelectionSheetState extends State<PackageSelectionSheet> {
  final CatalogService _catalogService = CatalogService();

  late Package _selectedPackage;
  PlanDuration? _selectedDuration;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    if (widget.packages.isEmpty) return;

    if (widget.initialSelectedPackageId != null) {
      _selectedPackage = widget.packages.firstWhere(
        (p) => p.id == widget.initialSelectedPackageId,
        orElse: () => widget.packages.first,
      );
    } else {
      _selectedPackage = widget.packages.first;
    }

    _syncSelectedDuration();
  }

  /// Ensures selected duration is valid for the currently selected package.
  /// If the current duration is not offered, automatically selects the first available duration.
  void _syncSelectedDuration() {
    final available = _selectedPackage.availableDurations;
    if (available.isNotEmpty) {
      if (_selectedDuration == null || !available.contains(_selectedDuration)) {
        _selectedDuration = available.first;
      }
    } else {
      _selectedDuration = null;
    }
  }

  void _onPackageSelected(Package pkg) {
    setState(() {
      _selectedPackage = pkg;
      _errorMessage = null;
      _syncSelectedDuration();
    });
  }

  Future<void> _handlePurchase() async {
    if (_selectedDuration == null) {
      setState(() {
        _errorMessage = "Please select an available plan duration.";
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Stubbed grantAccess call site (real payment gateway integration hooks here later)
      final result = await _catalogService.grantAccess(
        packageId: _selectedPackage.id,
        planDuration: _selectedDuration!,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentTeal,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );

          widget.onPurchaseSuccess?.call();
        } else {
          setState(() {
            _errorMessage = result.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.inkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'No purchase packages available for this item.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Available durations for the currently selected package ONLY
    final availableDurations = _selectedPackage.availableDurations;
    final selectedPrice = _selectedDuration != null ? _selectedPackage.priceFor(_selectedDuration!) : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_open, color: AppTheme.accentAmber, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock Full Notes',
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose a package tier and valid study duration',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1. Package Tier Picker
          const Text(
            '1. SELECT PACKAGE TIER',
            style: TextStyle(
              color: AppTheme.accentAmber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          Column(
            children: widget.packages.map((pkg) {
              final isSelected = pkg.id == _selectedPackage.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentAmber.withValues(alpha: 0.12) : AppTheme.inkDarker,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.accentAmber : Colors.white12,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onPackageSelected(pkg),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? AppTheme.accentAmber : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      pkg.title,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.textLight : AppTheme.textMuted,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.accentAmber.withValues(alpha: 0.25)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pkg.packageType.label,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.accentAmber : AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (pkg.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  pkg.description!,
                                  style: TextStyle(
                                    color: AppTheme.textMuted.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 2. Duration Picker
          // STRICT REQUIREMENT:
          // Shows ONLY the durations that package actually offers (subset of monthly/3mo/6mo/1yr)
          // with that package's own price for each.
          // Genuinely hides missing ones, not just visually disables them.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '2. SELECT PLAN DURATION',
                style: TextStyle(
                  color: AppTheme.accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${availableDurations.length} duration${availableDurations.length == 1 ? '' : 's'} offered',
                style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (availableDurations.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.inkDarker,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No plan durations currently configured for this package.',
                style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
              ),
            )
          else
            // We map ONLY availableDurations. Missing durations are NEVER inserted into the list.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableDurations.map((duration) {
                final isSelected = duration == _selectedDuration;
                final price = _selectedPackage.priceFor(duration)!;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _selectedDuration = duration;
                      _errorMessage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentAmber : AppTheme.inkDarker,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentAmber : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          duration.label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.inkDarker : AppTheme.textLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹$price',
                          style: TextStyle(
                            color: isSelected ? AppTheme.inkDarker : AppTheme.accentAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 3. Purchase Button
          ElevatedButton(
            onPressed: _isProcessing || _selectedDuration == null ? null : _handlePurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: AppTheme.inkDarker,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.inkDarker),
                    ),
                  )
                : Text(
                    selectedPrice != null
                        ? 'Unlock Access • ₹$selectedPrice'
                        : 'Select Plan Duration',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Secure direct access • Instant activation (Razorpay stub)',
              style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
