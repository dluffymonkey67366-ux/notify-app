import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'catalog/subject_list_screen.dart';
import 'library/library_screen.dart';
import 'reader/html/html_note_reader_screen.dart';
import 'reader/pdf/drm_pdf_reader_screen.dart';

/// AppShell: Adaptive navigation featuring Bottom Navigation Bar for compact/mobile screens
/// and an Editorial Side Navigation Rail for tablets, desktops, and web.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final themeController = Provider.of<ThemeController>(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSideNav = screenWidth >= NotifyBreakpoints.medium;

    final pages = [
      const LibraryScreen(),
      const _StudyReaderOverviewScreen(),
      const SubjectListScreen(),
      const _StudentProfileScreen(),
    ];

    if (isSideNav) {
      // Large Screen: Side Navigation Rail Layout
      return Scaffold(
        backgroundColor: theme.bg,
        body: Row(
          children: [
            // Editorial Side Navigation Rail
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: theme.bgDarker,
                border: Border(
                  right: BorderSide(color: theme.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // App Brand / Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: NotifyColors.goldGradient,
                            borderRadius: NotifyRadius.md,
                            boxShadow: [
                              BoxShadow(
                                color: NotifyColors.amber.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: NotifyColors.inkDarker,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTIFY',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  fontFamily: NotifyTypography.serifFamily,
                                ),
                              ),
                              Text(
                                'CA Study Companion',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.accentAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        _buildSideNavItem(
                          index: 0,
                          icon: Icons.local_library_outlined,
                          selectedIcon: Icons.local_library_rounded,
                          label: 'My Library',
                          badgeCount: '4',
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        _buildSideNavItem(
                          index: 1,
                          icon: Icons.auto_stories_outlined,
                          selectedIcon: Icons.auto_stories_rounded,
                          label: 'Reading Desk',
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        _buildSideNavItem(
                          index: 2,
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore_rounded,
                          label: 'ICAI Catalog',
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        _buildSideNavItem(
                          index: 3,
                          icon: Icons.account_circle_outlined,
                          selectedIcon: Icons.account_circle_rounded,
                          label: 'Student Account',
                          theme: theme,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Controls: Theme Toggle & Offline Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: NotifyRadius.md,
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    themeController.isDarkMode
                                        ? Icons.nightlight_round
                                        : Icons.wb_sunny_rounded,
                                    size: 16,
                                    color: theme.accentAmber,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      themeController.isDarkMode ? 'Ink Theme' : 'Paper Theme',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: themeController.isDarkMode,
                                activeColor: NotifyColors.amber,
                                activeTrackColor: NotifyColors.amber.withOpacity(0.3),
                                inactiveThumbColor: theme.textMuted,
                                onChanged: (_) => themeController.toggleTheme(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(Icons.cloud_done_rounded, size: 14, color: NotifyColors.teal),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Offline Sync Ready',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: NotifyColors.teal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main Content Area
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    } else {
      // Compact Screen: Bottom Navigation Bar Layout
      return Scaffold(
        backgroundColor: theme.bg,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.bgDarker,
            border: Border(
              top: BorderSide(color: theme.border, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: theme.bgDarker,
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_library_outlined),
                selectedIcon: Icon(Icons.local_library_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_rounded),
                label: 'Study Desk',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Catalog',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                selectedIcon: Icon(Icons.account_circle_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSideNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    String? badgeCount,
    required NotifyThemeExtension theme,
  }) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: isSelected ? theme.accentAmber.withOpacity(0.15) : Colors.transparent,
      borderRadius: NotifyRadius.md,
      child: InkWell(
        onTap: () => _onDestinationSelected(index),
        borderRadius: NotifyRadius.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: NotifyRadius.md,
            border: isSelected
                ? Border.all(color: theme.accentAmber.withOpacity(0.4), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? theme.accentAmber : theme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? theme.accentAmber : theme.textPrimary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.accentAmber : theme.borderSubtle,
                    borderRadius: NotifyRadius.pill,
                  ),
                  child: Text(
                    badgeCount,
                    style: TextStyle(
                      color: isSelected
                          ? (context.isDarkMode ? NotifyColors.inkDarker : Colors.white)
                          : theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary screen: Reading Desk overview
class _StudyReaderOverviewScreen extends StatelessWidget {
  const _StudyReaderOverviewScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        title: const Text('CA Reading Desk'),
        backgroundColor: theme.bgDarker,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NotifyCard(
            isElevated: true,
            accentStripeColor: theme.accentAmber,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_added_rounded, color: NotifyColors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recently Opened Module',
                      style: TextStyle(
                        color: theme.accentAmber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Corporate Law • Chapter 3: Indemnity & Guarantee',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: theme.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Section 124 - Section 147 • ICAI Study Material Revised 2024',
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    NotifyButton(
                      label: 'Launch Reader Workspace',
                      leadingIcon: Icons.menu_book_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HtmlNoteReaderScreen(
                              partId: 'part_3a_indemnity_guarantee',
                              partTitle: 'Part A: Contract of Indemnity and Guarantee',
                              subjectTitle: 'CA Inter - Corporate and Other Laws',
                              initialRawHtml: '''
<h2>Chapter 3: The Indian Contract Act, 1872</h2>
<h3>Part A: Contract of Indemnity and Guarantee</h3>
<p><strong>Section 124: Contract of Indemnity</strong></p>
<p>A contract by which one party promises to save the other from loss caused to him by the conduct of the promisor himself, or by the conduct of any other person, is called a contract of indemnity.</p>
<p><strong>Section 126: Contract of Guarantee</strong></p>
<p>A contract of guarantee is a contract to perform the promise, or discharge the liability, of a third person in case of his default.</p>
''',
                            ),
                          ),
                        );
                      },
                    ),
                    NotifyButton(
                      label: 'Open DRM PDF Stream',
                      variant: NotifyButtonVariant.secondary,
                      leadingIcon: Icons.lock_clock_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DrmPdfReaderScreen(
                              partId: 'part_3a_indemnity_guarantee',
                              partTitle: 'Part A: Contract of Indemnity and Guarantee (DRM Stream)',
                              subjectTitle: 'CA Inter - Corporate and Other Laws',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Statutory Notes & Flashcards',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          NotifyCard(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined, color: NotifyColors.teal),
              title: Text(
                'AS 14 Amalgamation Summary Notes',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Includes purchase method vs pooling of interests',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          ),
          const SizedBox(height: 10),
          NotifyCard(
            child: ListTile(
              leading: const Icon(Icons.gavel_outlined, color: NotifyColors.coral),
              title: Text(
                'Direct Tax Rates for Assessment Year 2025-26',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'New Tax Regime vs Old Tax Regime slabs',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fourth screen: Student Account & Reading Preferences
class _StudentProfileScreen extends StatelessWidget {
  const _StudentProfileScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final themeController = Provider.of<ThemeController>(context);
    final authService = Provider.of<AuthService>(context);
    final sessionManager = SessionManager();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        title: const Text('Student Profile & Settings'),
        backgroundColor: theme.bgDarker,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Student Profile Card
          NotifyCard(
            isElevated: true,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.accentAmber.withOpacity(0.2),
                  child: const Icon(
                    Icons.person_rounded,
                    color: NotifyColors.amber,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'CA Student Aspirant',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? user?.phoneNumber ?? 'NRO0491823 • ICAI Registered',
                        style: TextStyle(color: theme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const NotifyTagBadge(
                        label: 'CA Intermediate • Group 1 & 2',
                        color: NotifyColors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Reading Mode & Appearance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Theme Switcher Card
          NotifyCard(
            child: SwitchListTile(
              secondary: Icon(
                themeController.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: theme.accentAmber,
              ),
              title: Text(
                'Dark Reading Mode (--ink)',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                themeController.isDarkMode
                    ? 'Active: Deep Ink (#1A1A2E) for eye-strain-free nighttime reading'
                    : 'Active: Warm Paper (#FAFAF7) for bright daytime reading',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              ),
              value: themeController.isDarkMode,
              activeColor: NotifyColors.amber,
              onChanged: (_) => themeController.toggleTheme(),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Device & Security',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Device Session Info
          NotifyCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phonelink_lock_rounded, color: NotifyColors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '1-Device Enforced Study Session',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Device ID: ${sessionManager.currentDeviceId ?? "Verified System"}',
                  style: TextStyle(color: theme.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Status: Active • Encrypted local cache enabled',
                  style: TextStyle(color: NotifyColors.teal, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sign Out Action
          NotifyButton.secondary(
            label: 'Sign Out Account',
            leadingIcon: Icons.logout_rounded,
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
    );
  }
}
