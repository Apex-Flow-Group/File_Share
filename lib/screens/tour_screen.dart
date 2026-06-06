import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../managers/permission_manager.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class TourScreen extends StatefulWidget {
  final SettingsService settings;
  const TourScreen({required this.settings, super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  bool _agreed = false;

  Future<void> _start() async {
    await PermissionManager.requestAll();
    await widget.settings.markIntroAsSeen();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HomeScreen(settings: widget.settings),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // ─── Header ───────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(24, isWide ? 32 : 20, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.fastAndSecure,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Features list ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: isWide
                        ? _buildWideFeatures(l10n, isDark)
                        : _buildNarrowFeatures(l10n, isDark),
                  ),
                ),

                // ─── Checkbox + Button ────────────────────────────────
                _buildBottom(l10n, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Wide: 2-column grid ───────────────────────────────────────────────────

  Widget _buildWideFeatures(AppLocalizations l10n, bool isDark) {
    final features = _features(l10n);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: features
          .map((f) => SizedBox(
                width: (MediaQuery.of(context).size.width.clamp(0, 680) - 52) /
                    2,
                child: _FeatureCard(feature: f, isDark: isDark),
              ))
          .toList(),
    );
  }

  // ─── Narrow: single column ─────────────────────────────────────────────────

  Widget _buildNarrowFeatures(AppLocalizations l10n, bool isDark) {
    return Column(
      children: _features(l10n)
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeatureCard(feature: f, isDark: isDark),
              ))
          .toList(),
    );
  }

  // ─── Bottom: checkbox + start button ─────────────────────────────────────

  Widget _buildBottom(AppLocalizations l10n, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Checkbox row
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _agreed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: _agreed
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: _agreed
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _agreeText(l10n),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Start button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _agreed ? 1.0 : 0.4,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _agreed ? _start : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.finish,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _agreeText(AppLocalizations l10n) {
    final isAr =
        Localizations.localeOf(context).languageCode == 'ar';
    return isAr
        ? 'قرأت المميزات وأوافق على منح الصلاحيات اللازمة للتطبيق'
        : 'I have read the features and agree to grant the required permissions';
  }

  List<_Feature> _features(AppLocalizations l10n) => [
        _Feature(
          icon: Icons.bolt_rounded,
          color: const Color(0xFFFF9500),
          title: l10n.feature1Title,
          desc: l10n.feature1Desc,
        ),
        _Feature(
          icon: Icons.wifi_off_rounded,
          color: const Color(0xFF34C759),
          title: l10n.feature2Title,
          desc: l10n.feature2Desc,
        ),
        _Feature(
          icon: Icons.lock_rounded,
          color: const Color(0xFF5856D6),
          title: l10n.feature3Title,
          desc: l10n.feature3Desc,
        ),
        _Feature(
          icon: Icons.sensors_rounded,
          color: const Color(0xFF007AFF),
          title: 'Nearby + WiFi',
          desc: Localizations.localeOf(context).languageCode == 'ar'
              ? 'اكتشاف تلقائي سريع عبر Nearby للهاتف أو mDNS للحاسوب'
              : 'Auto-discovery via Nearby for phones or mDNS for PC',
        ),
        _Feature(
          icon: Icons.phone_android_rounded,
          color: const Color(0xFFFF2D55),
          title: 'APK Sharing',
          desc: Localizations.localeOf(context).languageCode == 'ar'
              ? 'شارك تطبيقاتك المثبتة مع الأجهزة الأخرى'
              : 'Share your installed apps with other devices',
        ),
        _Feature(
          icon: Icons.devices_rounded,
          color: const Color(0xFF32ADE6),
          title: 'Multi-platform',
          desc: Localizations.localeOf(context).languageCode == 'ar'
              ? 'يعمل على الهاتف والتابلت وسطح المكتب'
              : 'Works on phone, tablet & desktop',
        ),
      ];
}

// ─── Feature Card ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _Feature(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final bool isDark;
  const _FeatureCard({required this.feature, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [feature.color, feature.color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: feature.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(feature.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
