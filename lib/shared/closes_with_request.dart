import 'package:flutter/widgets.dart';

import '../core/core_models.dart';

/// Removes the dialog or sheet it sits in once [request] is closed (the asker
/// stopped waiting), so a late "Accept" cannot look accepted.
class ClosesWithRequest extends StatefulWidget {
  const ClosesWithRequest({required this.request, required this.child, super.key});

  final ConnectionRequest request;
  final Widget child;

  @override
  State<ClosesWithRequest> createState() => _ClosesWithRequestState();
}

class _ClosesWithRequestState extends State<ClosesWithRequest> {
  @override
  void initState() {
    super.initState();
    widget.request.closed.then((_) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
