import 'dart:async';

import 'package:flutter/material.dart';

import 'ad_service.dart';

/// A pretend ad network for the web build and the test site: shows a
/// full-screen "ad" with a countdown, so the reward flow can be tried
/// without a real ad SDK.
class MockAdService implements AdService {
  MockAdService(this.navigatorKey, {this.seconds = 3});

  final GlobalKey<NavigatorState> navigatorKey;
  final int seconds;

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final watched = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) =>
            _FakeAd(seconds: seconds, rewarded: true, label: placement.name),
      ),
    );
    return watched ?? false;
  }

  @override
  Future<bool> showInterstitial() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) =>
            _FakeAd(seconds: seconds, rewarded: false, label: 'interstitial'),
      ),
    );
    return true;
  }

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class _FakeAd extends StatefulWidget {
  const _FakeAd({
    required this.seconds,
    required this.rewarded,
    required this.label,
  });

  final int seconds;
  final bool rewarded;
  final String label;

  @override
  State<_FakeAd> createState() => _FakeAdState();
}

class _FakeAdState extends State<_FakeAd> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.ondemand_video,
                    size: 72,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TEST AD (${widget.label})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    done ? 'Done!' : '$_left',
                    style: const TextStyle(color: Colors.white70, fontSize: 32),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                key: const ValueKey('fake_ad_close'),
                icon: const Icon(Icons.close, color: Colors.white),
                // Closing early forfeits the reward, like a real ad.
                onPressed: () =>
                    Navigator.pop(context, done && widget.rewarded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
