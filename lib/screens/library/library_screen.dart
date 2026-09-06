import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../models/study_package.dart';
import '../../services/progress_service.dart';
import '../reader/html/html_note_reader_screen.dart';
import 'widgets/hero_resume_card.dart';
import 'widgets/package_card.dart';

/// Notify Library / Home Screen
/// Shows purchased CA study packages as premium cards with expiry badges & offline indicators.
class LibraryScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const LibraryScreen({super.key, this.onOpenDrawer});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late List<StudyPackage> _packages;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _examDaysRemaining = 58;
  StudyProgress? _recentProgress;

  @override
  void initState() {
    super.initState();
    _packages = List.from(StudyPackage.mockPurchasedPackages);
    _loadProgressAndExamCountdown();
  }

  Future<void> _loadProgressAndExamCountdown() async {
    final days = await ProgressService().getExamDaysRemaining();
    final recent = await ProgressService().getRecentProgress();
    if (mounted) {
      setState(() {
        _examDaysRemaining = days;
        _recentProgress = recent;
      });
    }
  }

  StudyPackage get _activePackage {
    if (_recentProgress != null && _recentProgress!.partId.isNotEmpty) {
      for (final p in _packages) {
        if (p.id == _recentProgress!.partId) return p;
      }
    }
    return _packages.first;
  }

  Future<void> _showExamDateDialog() async {
    final theme = context.notifyTheme;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(days: _examDaysRemaining > 0 ? _examDaysRemaining : 60)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.accentAmber,
              onPrimary: Colors.black,
              surface: theme.cardBg,
              onSurface: theme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await ProgressService().setTargetExamDate(picked);
      await _loadProgressAndExamCountdown();
    }
  }

  List<StudyPackage> get _filteredPackages {
    return _packages.where((pkg) {
      final matchesSearch = _searchQuery.isEmpty ||
          pkg.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pkg.paperCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pkg.instructorName.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesFilter = true;
      if (_selectedFilter == 'Group 1') {
        matchesFilter = pkg.groupName == 'Group 1';
      } else if (_selectedFilter == 'Group 2') {
        matchesFilter = pkg.groupName == 'Group 2';
      } else if (_selectedFilter == 'Offline Ready') {
        matchesFilter = pkg.isOfflineAvailable;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _openReaderForPackage(StudyPackage pkg) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlNoteReaderScreen(
          partId: pkg.id,
          partTitle: pkg.lastReadChapterTitle,
          subjectTitle: '${pkg.courseLevel} • ${pkg.title}',
          initialRawHtml: '''
<h2>${pkg.title} (${pkg.paperCode})</h2>
<h3>${pkg.lastReadChapterTitle}</h3>
<p><strong>Faculty:</strong> ${pkg.instructorName} | <strong>Scheme:</strong> ${pkg.syllabusScheme}</p>
<hr style="border: 0; border-top: 1px solid rgba(229,169,59,0.3); margin: 16px 0;" />
<p><strong>Overview:</strong></p>
<p>Welcome to this core section of the ${pkg.title} syllabus. Under ICAI guidelines, this module carries substantial weightage in both descriptive questions and case scenario-based MCQs.</p>
<h4>Key Statutory Provisions:</h4>
<ul>
  <li>Section 124: Contract of Indemnity defined and key essentials.</li>
  <li>Section 126: Contract of Guarantee, Surety, Principal Debtor and Creditor definitions.</li>
  <li>Section 128: Co-extensive nature of surety's liability.</li>
</ul>
<blockquote>
  <em>"The liability of the surety is co-extensive with that of the principal debtor, unless it is otherwise provided by the contract."</em>
</blockquote>
<p>Ensure that you have revised all past examination questions and Mock Test Papers (MTP) before proceeding to practical illustrations.</p>
''',
        ),
      ),
    );
  }

  void _toggleOffline(StudyPackage pkg) {
    final idx = _packages.indexWhere((p) => p.id == pkg.id);
    if (idx != -1) {
      setState(() {
        final updated = StudyPackage(
          id: pkg.id,
          title: pkg.title,
          paperCode: pkg.paperCode,
          courseLevel: pkg.courseLevel,
          groupName: pkg.groupName,
          syllabusScheme: pkg.syllabusScheme,
          daysRemaining: pkg.daysRemaining,
          isOfflineAvailable: !pkg.isOfflineAvailable,
          offlineSizeBytes: !pkg.isOfflineAvailable ? 280 * 1024 * 1024 : 0,
          totalChapters: pkg.totalChapters,
          completedChapters: pkg.completedChapters,
          lastReadChapterTitle: pkg.lastReadChapterTitle,
          lastReadChapterNumber: pkg.lastReadChapterNumber,
          instructorName: pkg.instructorName,
          totalHours: pkg.totalHours,
          accentColor: pkg.accentColor,
          icon: pkg.icon,
        );
        _packages[idx] = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !pkg.isOfflineAvailable
                ? '${pkg.title} downloaded for offline reading'
                : 'Offline copy removed for ${pkg.title}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: !pkg.isOfflineAvailable ? NotifyColors.teal : NotifyColors.inkCard,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= NotifyBreakpoints.medium;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar / Greeting Area
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32.0 : 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    if (isDesktop)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'NOTIFY',
                                    style: TextStyle(
                                      color: theme.accentAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.accentAmber.withValues(alpha: 0.16),
                                      borderRadius: NotifyRadius.xs,
                                    ),
                                    child: Text(
                                      'STUDY PRO',
                                      style: TextStyle(
                                        color: theme.accentAmber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'My CA Library',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: theme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          NotifyExamCountdownBadge(
                            daysRemaining: _examDaysRemaining,
                            onTap: _showExamDateDialog,
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'NOTIFY',
                                    style: TextStyle(
                                      color: theme.accentAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.accentAmber.withValues(alpha: 0.16),
                                      borderRadius: NotifyRadius.xs,
                                    ),
                                    child: Text(
                                      'STUDY PRO',
                                      style: TextStyle(
                                        color: theme.accentAmber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              NotifyExamCountdownBadge(
                                daysRemaining: _examDaysRemaining,
                                onTap: _showExamDateDialog,
                                isCompact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'My CA Library',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: theme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Elevated HeroResumeCard placed below top app bar, above streak banner/search filters
                    if (_packages.isNotEmpty && _selectedFilter == 'All' && _searchQuery.isEmpty) ...[
                      HeroResumeCard(
                        package: _activePackage,
                        progress: _recentProgress,
                        onResume: () => _openReaderForPackage(_activePackage),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Daily Study Streak & Goal Banner
                    _buildStreakBanner(theme, isDesktop),

                    const SizedBox(height: 20),

                    // Search & Filter Bar
                    NotifySearchBar(
                      selectedFilter: _selectedFilter,
                      onChanged: (query) => setState(() => _searchQuery = query),
                      onFilterSelected: (filter) => setState(() => _selectedFilter = filter),
                    ),

                    const SizedBox(height: 24),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Purchased Packages',
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.borderSubtle,
                                  borderRadius: NotifyRadius.pill,
                                ),
                                child: Text(
                                  '${_filteredPackages.length}',
                                  style: TextStyle(
                                    color: theme.accentAmber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_packages.where((p) => p.isOfflineAvailable).length} Offline ready',
                          style: TextStyle(
                            color: NotifyColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Packages Content Grid / List
            if (_filteredPackages.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: theme.textSubtle),
                      const SizedBox(height: 12),
                      Text(
                        'No packages match your search',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try adjusting your search query or filters',
                        style: TextStyle(
                          color: theme.textSubtle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32.0 : 20.0,
                  vertical: 8.0,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final int crossAxisCount = width >= 1100 ? 3 : (width >= 680 ? 2 : 1);

                    if (crossAxisCount == 1) {
                      // Single column list on compact screens
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pkg = _filteredPackages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: PackageCard(
                                package: pkg,
                                onOpenReader: () => _openReaderForPackage(pkg),
                                onToggleOffline: () => _toggleOffline(pkg),
                              ),
                            );
                          },
                          childCount: _filteredPackages.length,
                        ),
                      );
                    } else {
                      // Multi-column grid on tablets / desktop
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 18.0,
                          mainAxisSpacing: 18.0,
                          mainAxisExtent: 430.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pkg = _filteredPackages[index];
                            return PackageCard(
                              package: pkg,
                              onOpenReader: () => _openReaderForPackage(pkg),
                              onToggleOffline: () => _toggleOffline(pkg),
                            );
                          },
                          childCount: _filteredPackages.length,
                        ),
                      );
                    }
                  },
                ),
              ),

            // Bottom Spacing for navigation bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBanner(NotifyThemeExtension theme, bool isDesktop) {
    return NotifyCard(
      isElevated: true,
      backgroundColor: theme.cardElevatedBg,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.accentAmber.withValues(alpha: 0.18),
              borderRadius: NotifyRadius.md,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: NotifyColors.amber,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '14-Day Study Streak',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '🔥 Active',
                      style: TextStyle(
                        color: theme.accentAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Today: 3.5 hrs studied • 1.5 hrs remaining to daily goal',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            NotifyButton.secondary(
              label: 'View Study Plan',
              isCompact: true,
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }
}
