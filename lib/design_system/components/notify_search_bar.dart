import 'package:flutter/material.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../notify_theme.dart';

/// Notify Search Bar with Filter Chips
class NotifySearchBar extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFilterSelected;
  final String selectedFilter;
  final List<String> filters;
  final String hintText;

  const NotifySearchBar({
    super.key,
    this.onChanged,
    this.onFilterSelected,
    this.selectedFilter = 'All',
    this.filters = const ['All', 'Group 1', 'Group 2', 'Offline Ready'],
    this.hintText = 'Search CA notes, sections, standards...',
  });

  @override
  State<NotifySearchBar> createState() => _NotifySearchBarState();
}

class _NotifySearchBarState extends State<NotifySearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Input Box
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: NotifyRadius.md,
            border: Border.all(color: theme.border, width: 1),
          ),
          child: TextField(
            controller: _controller,
            onChanged: (val) {
              setState(() => _hasText = val.isNotEmpty);
              widget.onChanged?.call(val);
            },
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: theme.textSubtle,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.accentAmber,
                size: 20,
              ),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.textMuted),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _hasText = false);
                        widget.onChanged?.call('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: widget.filters.map((filter) {
              final isSelected = widget.selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (context.isDarkMode ? NotifyColors.inkDarker : Colors.white)
                          : theme.textMuted,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => widget.onFilterSelected?.call(filter),
                  backgroundColor: theme.cardBg,
                  selectedColor: theme.accentAmber,
                  checkmarkColor: context.isDarkMode ? NotifyColors.inkDarker : Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: NotifyRadius.pill,
                    side: BorderSide(
                      color: isSelected ? theme.accentAmber : theme.border,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
