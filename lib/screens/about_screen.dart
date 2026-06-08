import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';

const _kPlayStoreUrl =
    'https://play.google.com/store/apps/dev?id=5409981776310932919';

class AboutScreen extends StatefulWidget {
  final bool embedded;
  const AboutScreen({this.embedded = false, super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = 'v${info.version}');
    } catch (_) {
      setState(() => _version = 'v1.0.0');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _buildContent(context, l10n);
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutApp)),
      body: Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      )),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // أيقونة التطبيق
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/ico.png',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        const Text('Apex Transfer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(_version, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(l10n.appDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 28),
        // ── Android QR (Desktop only) ──────────────────────────
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
          _buildAndroidCard(context),
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
          const SizedBox(height: 20),
        // ──────────────────────────────────────────────────────
        _buildSection(l10n.importantLinks, [
          _buildLink(
            context,
            isAr ? 'الموقع الرسمي' : 'Official Website',
            'https://apexflow.now/en',
            icon: Icons.language_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          _buildLink(
            context,
            l10n.privacyPolicy,
            'https://apexflow.now/en/projects/apex-file-share/privacy',
          ),
          _buildLink(
            context,
            'GitHub',
            'https://github.com/Apex-Flow-Group/File_Share',
            icon: Icons.code_rounded,
            color: Colors.grey[700]!,
          ),
        ]),
        const SizedBox(height: 20),
        _buildSection(l10n.legalInfo, [
          _buildLegalText(l10n.disclaimer, l10n.disclaimerText),
          _buildLegalText(l10n.copyright, l10n.copyrightText),
        ]),
        const SizedBox(height: 28),
        Text(l10n.madeInArabWorld,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const Text('contact.apex.flow@gmail.com',
            style: TextStyle(fontSize: 12, color: Colors.blue)),
      ],
    );
  }

  Widget _buildAndroidCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    const color = Color(0xFF34C759);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.android_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'حمّل على أندرويد' : 'Get on Android',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    isAr ? 'امسح الباركود بهاتفك' : 'Scan with your phone',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // QR Code
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: _kPlayStoreUrl,
                  version: QrVersions.auto,
                  size: 120,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'أو اضغط على الزر' : 'Or tap the button',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _launchUrl(_kPlayStoreUrl),
                        icon: const Icon(Icons.shop_rounded, size: 18),
                        label: Text(
                          isAr ? 'Google Play' : 'Google Play',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildLink(BuildContext context, String title, String url,
      {IconData icon = Icons.link, Color? color}) {
    final linkColor = color ?? Colors.blue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Row(children: [
          Icon(icon, size: 16, color: linkColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: linkColor,
                    decoration: TextDecoration.underline,
                    decorationColor: linkColor)),
          ),
          Icon(Icons.arrow_outward, size: 14, color: linkColor),
        ]),
      ),
    );
  }

  Widget _buildLegalText(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(content,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
