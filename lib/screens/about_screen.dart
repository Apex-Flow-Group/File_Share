import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

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
    } catch (e) {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutApp)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 800 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWideScreen ? 32 : 16),
            child: Column(
              children: [
                const Icon(Icons.share, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Apex File Share',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(_version, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(l10n.appDescription),
                const SizedBox(height: 32),
                _buildSection(l10n.importantLinks, [
                  _buildLink(context, l10n.privacyPolicy, 'https://apexflow.dev/privacy'),
                  _buildLink(context, l10n.termsOfService, 'https://apexflow.dev/terms'),
                ]),
                const SizedBox(height: 24),
                _buildSection(l10n.legalInfo, [
                  _buildLegalText(l10n.disclaimer, l10n.disclaimerText),
                  _buildLegalText(l10n.copyright, l10n.copyrightText),
                ]),
                const SizedBox(height: 32),
                Text(l10n.madeInArabWorld,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('contact.apex.flow@gmail.com',
                    style: TextStyle(fontSize: 12, color: Colors.blue)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildLink(BuildContext context, String title, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Row(
          children: [
            const Icon(Icons.link, size: 18, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline)),
            ),
            const Icon(Icons.arrow_outward, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalText(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Text(content,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
