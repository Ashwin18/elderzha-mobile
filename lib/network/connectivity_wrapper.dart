import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'internet_error_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  late Connectivity _connectivity;
  List<ConnectivityResult>? _results;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _initConnectivity();
    _sub = _connectivity.onConnectivityChanged.listen(_update);
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  Future<void> _initConnectivity() async {
    try {
      _results = await _connectivity.checkConnectivity();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _update(List<ConnectivityResult> results) {
    if (mounted) setState(() => _results = results);
  }

  bool get _hasConnection {
    if (_results == null || _results!.isEmpty) return true; // assume online until known
    return _results!.any((r) => r != ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    // Draw the offline screen ON TOP of the app instead of replacing it.
    // Replacing it threw away the whole Navigator, so a short signal drop
    // restarted the app at the splash screen and lost whatever the user
    // was typing or paying for.
    if (_hasConnection) return widget.child;
    return Stack(
      children: [
        widget.child,
        const Positioned.fill(child: InternetErrorScreen()),
      ],
    );
  }
}
