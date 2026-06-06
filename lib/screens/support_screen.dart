import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../utils/snackbar_helper.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = info.version);
    } catch (e) {
      setState(() => _version = '2.0.1');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text;
      final email = _emailController.text;
      final subject = _subjectController.text;
      final category = _selectedCategory ?? 'أخرى';

      final body = '''الاسم: $name
البريد: $email
الفئة: $category

الرسالة:
${_bodyController.text}

---
معلومات الجهاز:
النظام: ${Platform.operatingSystem}
الإصدار: $_version''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'contact.apex.flow@gmail.com',
        query: _encodeQueryParameters({
          'subject': '[Apex File Share] $subject',
          'body': body,
        }),
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _clearForm();
          SnackBarHelper.showSuccess(context, l10n.emailOpened);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _bodyController.clear();
    _selectedCategory = null;
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = [l10n.inquiry, l10n.technicalIssue, l10n.suggestion, l10n.other];
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactUs)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 800 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWideScreen ? 32 : 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    l10n.weAreHappyToHear,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  if (isWideScreen)
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nameController,
                            label: l10n.yourName,
                            icon: Icons.person,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: l10n.email,
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildTextField(
                      controller: _nameController,
                      label: l10n.yourName,
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: l10n.email,
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: l10n.category,
                    value: _selectedCategory,
                    items: categories,
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _subjectController,
                    label: l10n.subject,
                    icon: Icons.subject,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _bodyController,
                    label: l10n.message,
                    icon: Icons.description,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isWideScreen ? 300 : double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _submitForm,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isLoading ? l10n.sending : l10n.sendMessage),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        final l10n = AppLocalizations.of(context);
        return value == null || value.isEmpty ? l10n.fieldRequired : null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) {
        final l10n = AppLocalizations.of(context);
        return value == null ? l10n.fieldRequired : null;
      },
    );
  }
}
