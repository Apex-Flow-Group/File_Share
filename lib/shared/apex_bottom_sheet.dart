import 'package:flutter/material.dart';

/// Bottom sheet موحد بتصميم Apex — يُستخدم بدلاً من تكرار نفس الهيكل
class ApexBottomSheet extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const ApexBottomSheet(
      {required this.child, this.scrollable = false, super.key});

  /// عرض bottom sheet عائم بالتصميم الموحد
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool scrollable = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      builder: (_) => ApexBottomSheet(
        scrollable: scrollable,
        child: child,
      ),
    );
  }

  /// عرض bottom sheet بهيدر ملون + محتوى + أزرار (النمط الأكثر تكراراً)
  static Future<T?> showStyled<T>(
    BuildContext context, {
    required IconData headerIcon,
    required Color headerColor,
    required String headerTitle,
    required Widget content,
    required List<Widget> actions,
    String? headerSubtitle,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Handle
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ─── Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              headerColor.withValues(alpha: 0.15),
                              headerColor.withValues(alpha: 0.03),
                            ]
                          : [
                              headerColor.withValues(alpha: 0.1),
                              headerColor.withValues(alpha: 0.02),
                            ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: headerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(headerIcon, color: headerColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitle,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (headerSubtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                headerSubtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ─── Content (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: content,
                  ),
                ),
                // ─── Actions (fixed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(children: actions),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// عرض bottom sheet بنمط اختيار (picker) — نفس شكل الإعدادات
  ///
  /// يعرض عنوان + قائمة عناصر مع أيقونة + علامة اختيار للعنصر المحدد.
  /// مثال:
  /// ```dart
  /// ApexBottomSheet.showPicker(context,
  ///   title: 'اختر اللغة',
  ///   items: [
  ///     PickerItem(label: 'العربية', value: 'ar', icon: Icons.translate),
  ///     PickerItem(label: 'English', value: 'en', icon: Icons.translate),
  ///   ],
  ///   currentValue: 'ar',
  ///   onSelected: (v) => print(v),
  /// );
  /// ```
  static void showPicker({
    required BuildContext context,
    required String title,
    required List<PickerItem> items,
    required dynamic currentValue,
    required Function(dynamic) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    )),
              ),
              ...items.map((item) {
                final isSelected = item.value == currentValue;
                return ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        size: 18,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                  ),
                  title: Text(item.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(item.value);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheet = Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          scrollable
              ? Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: child,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: child,
                ),
        ],
      ),
    );

    return scrollable
        ? DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, __) => SafeArea(top: false, child: sheet),
          )
        : SafeArea(top: false, child: SingleChildScrollView(child: sheet));
  }
}

/// عنصر واحد في قائمة الاختيار (picker).
class PickerItem {
  final String label;
  final dynamic value;
  final IconData icon;
  const PickerItem(
      {required this.label, required this.value, required this.icon});
}
