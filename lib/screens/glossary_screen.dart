import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_route.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';

/// A permanent, always-unlocked lookup of every term in the app — the
/// answer to "I just heard 'DNSH' in a meeting, what does that mean?"
/// without needing to hunt through the module a term happens to live in.
/// Every card uses the same rich format as the flashcard, so a looked-up
/// term is just as useful as one studied properly.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Term> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return MockData.allTerms;
    return MockData.allTerms.where((t) {
      return t.term.toLowerCase().contains(q) ||
          t.definition.toLowerCase().contains(q) ||
          (t.plainEnglish?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // Terms don't all carry a stable id yet (migration is ongoing module by
  // module) — falling back to the term name keeps every row toggleable
  // either way, since term names are unique across the database.
  String _keyFor(Term t) => t.id ?? t.term;

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Glossary',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MockData.allTerms.length} terms — search any of them, any time.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSearchField(),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        key: const Key('glossary-list'),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildTermCard(results[index]),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          current: AppTab.glossary,
          onPathTap: () => Navigator.of(context).pop(),
          onGlossaryTap: () {},
          onStatsTap: () => Navigator.of(
            context,
          ).pushReplacement(appRoute(const StatsScreen())),
          onProfileTap: () => Navigator.of(
            context,
          ).pushReplacement(appRoute(const ProfileScreen())),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        key: const Key('glossary-search-field'),
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(fontSize: 14.5, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search DNSH, Scope 3, materiality...',
          hintStyle: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.inkSoft,
            size: 20,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.inkSoft,
                    size: 18,
                  ),
                  onPressed: () {
                    AppFeedback.tap();
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: AppColors.inkSoft, size: 36),
            const SizedBox(height: 10),
            Text(
              'No terms match "$_query"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermCard(Term term) {
    final key = _keyFor(term);
    final isExpanded = _expanded.contains(key);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('glossary-term-${term.term}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AppFeedback.tap();
          setState(() {
            if (isExpanded) {
              _expanded.remove(key);
            } else {
              _expanded.add(key);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (term.theme != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  color: term.theme!.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                term.term,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                term.moduleLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: AppColors.tealDeep,
                                ),
                              ),
                            ),
                            if (term.theme != null) ...[
                              const Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              Text(
                                term.theme!.label,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: term.theme!.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.inkSoft,
                      size: 22,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDetail(term),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(Term term) {
    if (!term.hasRichFormat) {
      return Text(
        term.definition,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.ink,
          height: 1.4,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('IN PLAIN ENGLISH', term.plainEnglish!, AppColors.tealDeep),
        if (term.whyItMatters != null) ...[
          const SizedBox(height: 10),
          _section('WHY IT MATTERS', term.whyItMatters!, AppColors.tealDeep),
        ],
        if (term.example != null) ...[
          const SizedBox(height: 10),
          _section('EXAMPLE', term.example!, AppColors.tealDeep),
        ],
        if (term.dontConfuseWith != null) ...[
          const SizedBox(height: 10),
          _section(
            "DON'T CONFUSE WITH",
            term.dontConfuseWith!,
            AppColors.amberDeep,
          ),
        ],
      ],
    );
  }

  Widget _section(String label, String body, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.ink,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
