import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/app_block_service.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';

/// Full-screen app picker that scans the device for installed apps.
///
/// Each app shows its icon, display name, and a toggle switch (styled to match
/// the Wind Down screen). Flipping a toggle instantly persists the change to
/// the database — no separate Save/Done step.
///
/// A "Show system apps" toggle at the top (default off) filters out
/// pre-installed system apps. Pull-to-refresh triggers a fresh device scan.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AppBlockService _blocker = AppBlockService.instance;
  final DatabaseHelper _db = DatabaseHelper();

  bool _loading = true;
  bool _showSystem = false;
  String _searchQuery = '';

  /// Full list of apps from the device scan, with isBlocked state merged from DB.
  List<_AppInfo> _allApps = [];

  /// Filtered (search + system-toggle) list for display.
  List<_AppInfo> get _filteredApps {
    var list = _allApps;
    if (!_showSystem) {
      list = list.where((a) => !a.isSystem).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((a) =>
              a.displayName.toLowerCase().contains(q) ||
              a.packageName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  int get _blockedCount => _allApps.where((a) => a.isBlocked).length;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
    _scanDevice();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Scan the device for installed apps and merge block states from the DB.
  Future<void> _scanDevice() async {
    setState(() => _loading = true);

    try {
      // Get installed apps from native side
      final installed = await _blocker.getInstalledApps();

      // Get existing block states from DB
      final existing = await _db.getAllBlockedApps();
      final blockedPkgs = <String>{};
      for (final row in existing) {
        if ((row['is_blocked'] as int?) == 1) {
          blockedPkgs.add(row['package_name'] as String);
        }
      }

      // Merge: native list is the source of truth; DB states overlay on top
      final merged = installed.map((m) {
        final pkg = m['packageName'] as String? ?? '';
        final name = m['displayName'] as String? ?? pkg;
        final icon = m['iconBase64'] as String? ?? '';
        final isSystem = m['isSystem'] as bool? ?? false;

        // Use DB state if it exists, otherwise default to blocked=false
        final isBlocked = blockedPkgs.contains(pkg);

        return _AppInfo(
          packageName: pkg,
          displayName: name,
          iconBase64: icon,
          isSystem: isSystem,
          isBlocked: isBlocked,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allApps = merged;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AppPickerScreen: scan failed – $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Flip a single app's block state and persist immediately.
  Future<void> _toggleApp(_AppInfo app) async {
    final newBlocked = !app.isBlocked;
    // Optimistic UI update
    setState(() {
      app.isBlocked = newBlocked;
    });
    // Persist instantly — matches Wind Down toggle behaviour
    await _db.setAppBlocked(
      app.packageName,
      app.displayName,
      isBlocked: newBlocked,
      isSystem: app.isSystem,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          color: AppColors.textSecondary, size: 22),
                    ),
                    Text('Block Apps', style: AppTextStyles.eyebrow()),
                    const SizedBox(width: 22),
                  ],
                ),
              ),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Toggle apps on to block them during focus sessions',
                  style: AppTextStyles.body(
                      size: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),

              // Search field
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle:
                        const TextStyle(fontSize: 14, color: Color(0xFF8A87B0)),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textSecondary),
                    suffixIcon: _searchIcon(),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Show system apps toggle + blocked count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    // "Show system apps" toggle row
                    GestureDetector(
                      onTap: () => setState(() => _showSystem = !_showSystem),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _showSystem
                              ? AppColors.sage.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showSystem
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 14,
                              color: _showSystem
                                  ? AppColors.sage
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Show system apps',
                              style: AppTextStyles.body(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: _showSystem
                                      ? AppColors.sage
                                      : AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Blocked count chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _blockedCount > 0
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_blockedCount blocked',
                        style: AppTextStyles.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: _blockedCount > 0
                                ? AppColors.accent
                                : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // App list with pull-to-refresh
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _allApps.isEmpty
                        ? _buildEmptyState()
                        : _filteredApps.isEmpty
                            ? _buildNoMatchState()
                            : RefreshIndicator(
                                onRefresh: _scanDevice,
                                color: AppColors.accent,
                                backgroundColor: AppColors.bgMid,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _filteredApps.length,
                                  itemBuilder: (context, index) {
                                    final app = _filteredApps[index];
                                    return _appTile(app);
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================== Widgets ========================

  Widget _appTile(_AppInfo app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: app.isBlocked
            ? AppColors.accent.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: app.iconBase64.isNotEmpty
                ? Image.memory(
                    _base64ToBytes(app.iconBase64),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconPlaceholder(),
                  )
                : _iconPlaceholder(),
          ),
          const SizedBox(width: 12),
          // Name + package
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.displayName,
                    style: AppTextStyles.body(
                        size: 13.5, weight: FontWeight.w500)),
                Row(
                  children: [
                    if (app.isSystem)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.plum.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('System',
                            style: AppTextStyles.body(
                                size: 8,
                                weight: FontWeight.w600,
                                color: AppColors.plum)),
                      ),
                    Expanded(
                      child: Text(app.packageName,
                          style: AppTextStyles.body(
                              size: 10, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Toggle switch (matches Wind Down screen style)
          Switch(
            value: app.isBlocked,
            onChanged: (_) => _toggleApp(app),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  Widget _iconPlaceholder() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.android, size: 18, color: AppColors.textMuted),
    );
  }

  Widget? _searchIcon() {
    if (_searchQuery.isEmpty) return null;
    return GestureDetector(
      onTap: () {
        _searchCtrl.clear();
        setState(() => _searchQuery = '');
      },
      child: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textMuted.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.smartphone_rounded,
                size: 28, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 12),
          Text('No apps found',
              style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Make sure your device has apps installed\nand try pulling down to refresh',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchState() {
    return ListView(
      // Makes the empty state scrollable so pull-to-refresh still works
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textMuted.withValues(alpha: 0.1),
                  ),
                  child: Icon(Icons.search_off_rounded,
                      size: 28,
                      color: AppColors.textMuted.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 12),
                Text('No apps match',
                    style: AppTextStyles.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text('Try a different search term',
                    style: AppTextStyles.body(
                        size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Decode a base64 string to a Uint8List for use with Image.memory.
  static Uint8List _base64ToBytes(String base64) {
    // Strip any data URI prefix if present
    final data = base64.contains(',') ? base64.split(',').last : base64;
    return Uint8List.fromList(const Base64Decoder().convert(data));
  }
}

/// Internal model for an installed app with its block state.
class _AppInfo {
  final String packageName;
  final String displayName;
  final String iconBase64;
  final bool isSystem;
  bool isBlocked;

  _AppInfo({
    required this.packageName,
    required this.displayName,
    required this.iconBase64,
    required this.isSystem,
    required this.isBlocked,
  });
}
