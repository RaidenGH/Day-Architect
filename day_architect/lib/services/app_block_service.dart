import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service that bridges to the native Android AppBlockerPlugin.
/// Detects when a blocked app (Instagram, TikTok, Facebook, etc.) is in the
/// foreground during a focus session and fires callbacks.
///
/// Android-only. On non-Android platforms all methods return false/null.
class AppBlockService {
  static const _channel = MethodChannel('day_architect/app_blocker');

  // Singleton
  AppBlockService._();
  static final AppBlockService instance = AppBlockService._();

  // ---------------------------------------------------------------------------
  // Stream for foreground app changes (only emitted while monitoring)
  // ---------------------------------------------------------------------------

  final StreamController<String> _foregroundController =
      StreamController<String>.broadcast();

  Stream<String> get onForegroundAppChanged => _foregroundController.stream;

  /// Whether the user has granted Usage Access permission.
  Future<bool> get isUsageStatsGranted async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isUsageStatsGranted') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Open system settings so the user can grant Usage Access.
  Future<void> openUsageStatsSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } on MissingPluginException {
      // no-op
    }
  }

  /// Get the current foreground app's package name (one-shot check).
  Future<String?> getCurrentForegroundPackage() async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getCurrentForegroundPackage');
    } on MissingPluginException {
      return null;
    }
  }

  /// Check if the current foreground app is in the [blocked] list.
  Future<bool> isBlocked(List<String> blocked) async {
    if (!isAndroid || blocked.isEmpty) return false;
    try {
      return await _channel
              .invokeMethod<bool>('isBlockable', {'blocked': blocked}) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Get the default list of social-media packages to block.
  Future<List<String>> getDefaultBlockedPackages() async {
    if (!isAndroid) return _fallbackBlocked;
    try {
      final pkgs =
          await _channel.invokeMethod<List<dynamic>>('getDefaultBlockedPackages');
      return pkgs?.cast<String>() ?? _fallbackBlocked;
    } on MissingPluginException {
      return _fallbackBlocked;
    }
  }

  /// Get all installed launcher apps (including system apps).
  /// Returns a list of maps with keys: packageName, displayName, iconBase64, isSystem.
  /// Sorted alphabetically by display name.
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    if (!isAndroid) return [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return [];
      // Use Map<String, dynamic>.from() instead of .cast() because
      // MethodChannel deserializes Kotlin maps as Map<Object?, Object?>,
      // and .cast<Map<String, dynamic>>() fails with invariant generics.
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'packageName': m['packageName'] as String? ?? '',
          'displayName': m['displayName'] as String? ?? 'Unknown',
          'iconBase64': m['iconBase64'] as String? ?? '',
          'isSystem': m['isSystem'] as bool? ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('AppBlockService.getInstalledApps failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Monitoring (used during active focus session)
  // ---------------------------------------------------------------------------

  Timer? _foregroundTimer;
  List<String> _blockedPackages = [];

  /// Whether the foreground monitor timer is currently active.
  bool get isMonitoring => _foregroundTimer != null;

  /// The currently configured blocked package list.
  List<String> get blockedPackages => _blockedPackages;

  /// Start polling the native side every [intervalMs] milliseconds.
  /// Each time the foreground app changes, the [onForegroundAppChanged] stream
  /// fires. The caller (e.g. FocusProvider) should subscribe to detect blocked
  /// apps and count interruptions.
  Future<void> startMonitoring({
    List<String>? blocked,
    int intervalMs = 2000,
    void Function(String package)? onBlocked,
  }) async {
    await stopMonitoring();

    _blockedPackages = blocked ?? await getDefaultBlockedPackages();

    // Native one-shot monitoring (set state, no polling loop)
    if (isAndroid) {
      try {
        await _channel.invokeMethod('startMonitoring', {'intervalMs': intervalMs});
      } on MissingPluginException {
        // no-op
      }
    }

    // Dart-side polling (the actual detection mechanism)
    _foregroundTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) async {
        if (!isAndroid) return;
        try {
          final pkg = await getCurrentForegroundPackage();
          if (pkg != null) {
            _foregroundController.add(pkg);
          }
        } catch (_) {}
      },
    );
  }

  /// Stop monitoring foreground apps.
  Future<void> stopMonitoring() async {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    if (isAndroid) {
      try {
        await _channel.invokeMethod('stopMonitoring');
      } on MissingPluginException {
        // no-op
      }
    }
  }

  /// Whether the given package name is in the blocked list.
  bool isBlockedPackage(String package) => _blockedPackages.contains(package);

  /// Dispose the service (called from app shutdown).
  void dispose() {
    _foregroundTimer?.cancel();
    _foregroundController.close();
  }

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  bool get isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static const _fallbackBlocked = <String>[
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.ss.android.ugc.trill', // TikTok (alt)
    'com.facebook.katana', // Facebook
    'com.facebook.orca', // Messenger
    'com.twitter.android', // X / Twitter
    'com.snapchat.android',
    'com.spotify.music',
    'com.netflix.mediaclient',
    'com.google.android.youtube',
  ];

  /// Human-readable names for known package names.
  static const wellKnownPackages = <String, String>{
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok',
    'com.facebook.katana': 'Facebook',
    'com.facebook.orca': 'Messenger',
    'com.twitter.android': 'X / Twitter',
    'com.snapchat.android': 'Snapchat',
    'com.spotify.music': 'Spotify',
    'com.netflix.mediaclient': 'Netflix',
    'com.google.android.youtube': 'YouTube',
  };

  /// Get a human-friendly name for a package, falling back to the raw name.
  static String friendlyName(String package) =>
      wellKnownPackages[package] ?? package.split('.').last;

  // ======================== System Overlay Freeze ========================

  /// Whether the SYSTEM_ALERT_WINDOW overlay permission is granted.
  Future<bool> get canDrawOverlays async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Open system settings so the user can grant overlay permission.
  Future<void> openOverlaySettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } on MissingPluginException {
      // no-op
    }
  }

  /// Show a full-screen system overlay on top of the blocked app,
  /// effectively freezing it until the user taps to return.
  Future<void> showBlockOverlay({required String appName}) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod(
        'showBlockOverlay',
        {'appName': appName},
      );
    } on MissingPluginException {
      // no-op
    }
  }

  /// Dismiss the block overlay (safe to call even if not showing).
  Future<void> dismissBlockOverlay() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('dismissBlockOverlay');
    } on MissingPluginException {
      // no-op
    }
  }
}
