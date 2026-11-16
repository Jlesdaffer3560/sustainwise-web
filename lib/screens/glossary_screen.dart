import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../data/models.dart';
import '../data/progress_store.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../web/responsive.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_route.dart';
import '../widgets/share_card.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'stats_screen.dart';

/// A permanent, always-unlocked lookup of every term in the app — the
/// answer to "I just heard 'DNSH' in a meeting, what does that mean?"
/// without needing to hunt through the module a term happens to live in.
/// Every card uses the same rich format as the flashcard, so a looked-up
/// term is just as useful as one studied properly.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, this.initialQuery});

  // Set only by the web dashboard's search bar, which lets a visitor type a
  // term before ever opening Glossary itself — the native app never passes
  // this, so its Glossary always opens on the full, unfiltered list exactly
  // as before.
  final String? initialQuery;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  late final _searchController = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late String _query = widget.initialQuery ?? '';
  final Set<String> _expanded = {};
  bool _onlyFavorites = false;
  final _listController = ScrollController();
  Timer? _urlSyncDebounce;

  @override
  void dispose() {
    _urlSyncDebounce?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // Browser back/forward between two /glossary?q=... URLs reuses this same
  // State object rather than recreating it (same route, same widget slot)
  // — without this, the search field and results would keep showing
  // whatever query was active when the screen was first built, ignoring
  // the URL the user just navigated back to.
  @override
  void didUpdateWidget(covariant GlossaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialQuery ?? '';
    if (incoming != oldWidget.initialQuery && incoming != _query) {
      _query = incoming;
      _searchController.text = incoming;
    }
  }

  // Keeps the address bar in sync while typing — a query someone shares or
  // bookmarks, or gets back via the browser's back button, actually
  // restores what they were searching for. Debounced and via replace (not
  // push), so it doesn't flood browser history with one entry per
  // keystroke. Native never calls this (no go_router there).
  void _scheduleUrlSync(String value) {
    if (!kIsWeb) return;
    _urlSyncDebounce?.cancel();
    _urlSyncDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final q = value.trim();
      GoRouter.of(context).replace(
        q.isEmpty ? '/glossary' : '/glossary?q=${Uri.encodeQueryComponent(q)}',
      );
    });
  }

  List<Term> get _filtered {
    final q = _query.trim().toLowerCase();
    final pool = _onlyFavorites
        ? MockData.allTerms
              .where((t) => ProgressStore.instance.isFavorite(_keyFor(t)))
              .toList()
        : MockData.allTerms;
    if (q.isEmpty) return pool;
    final matches = pool.where((t) {
      return t.term.toLowerCase().contains(q) ||
          t.definition.toLowerCase().contains(q) ||
          (t.plainEnglish?.toLowerCase().contains(q) ?? false);
    }).toList();
    // A hit in the term's own name ranks above one that only turns up
    // inside its definition or plain-English text — otherwise a query like
    // "sust" gets buried under every term that merely mentions
    // "sustainability" in passing, instead of surfacing terms actually
    // named for it (e.g. "Sustainable Development Goals").
    int rank(Term t) {
      final name = t.term.toLowerCase();
      if (name.startsWith(q)) return 0;
      if (name.contains(q)) return 1;
      return 2;
    }

    matches.sort((a, b) {
      final rankDiff = rank(a).compareTo(rank(b));
      if (rankDiff != 0) return rankDiff;
      return a.term.toLowerCase().compareTo(b.term.toLowerCase());
    });
    return matches;
  }

  // Terms don't all carry a stable id yet (migration is ongoing module by
  // module) — falling back to the term name keeps every row toggleable
  // either way, since term names are unique across the database.
  String _keyFor(Term t) => t.id ?? t.term;

  // On web, a visitor looking up a term most likely wants to copy its
  // definition into an email or a compliance note — Flutter renders
  // everything to a canvas by default, so text isn't selectable at all
  // unless explicitly wrapped in a SelectionArea. Native is untouched:
  // long-press-to-select isn't part of the app's existing interactions,
  // and this only ever wraps content when kIsWeb.
  Widget _maybeSelectable(Widget child) =>
      kIsWeb ? SelectionArea(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    // "The Ledger" tokens only ever apply at the desktop-web breakpoint —
    // narrow web keeps the exact same look as native, per the standing
    // requirement that a small screen should still feel like the app.
    final ledger = isDesktopWeb(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: ledger ? LedgerColors.contentBg : AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ledger) ...[
                      Container(
                        padding: const EdgeInsets.only(bottom: 14),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: LedgerColors.border),
                          ),
                        ),
                        child: const Text(
                          'GLOSSARY',
                          style: TextStyle(
                            fontFamily: LedgerColors.fontMono,
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: LedgerColors.inkSoft,
                          ),
                        ),
                      ),
                      const Text(
                        'Look up a term',
                        style: TextStyle(
                          fontFamily: LedgerColors.fontSans,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: LedgerColors.ink,
                        ),
                      ),
                    ] else
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
                      style: TextStyle(
                        fontFamily: ledger ? LedgerColors.fontSans : null,
                        fontSize: 13,
                        color: ledger
                            ? LedgerColors.inkSoft
                            : AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSearchField(ledger),
                    const SizedBox(height: 10),
                    _buildFilterChips(ledger),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _buildEmptyState(ledger)
                    : _maybeSelectable(
                        ListView.separated(
                          key: const Key('glossary-list'),
                          controller: _listController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildTermCard(results[index], ledger),
                        ),
                      ),
              ),
            ],
          ),
        ),
        // On web, tab navigation lives in the sidebar (DesktopShell) instead
        // — but only once there's room for one.
        bottomNavigationBar: isDesktopWeb(context)
            ? null
            : AppBottomNav(
                current: AppTab.glossary,
                onPathTap: () => Navigator.of(context).pop(),
                onGlossaryTap: () {},
                // Web merges Stats+Profile into one ProgressScreen; native
                // keeps them separate.
                onStatsTap: () => Navigator.of(context).pushReplacement(
                  appRoute(
                    kIsWeb ? const ProgressScreen() : const StatsScreen(),
                  ),
                ),
                onProfileTap: () => Navigator.of(context).pushReplacement(
                  appRoute(
                    kIsWeb ? const ProgressScreen() : const ProfileScreen(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSearchField(bool ledger) {
    return Container(
      decoration: BoxDecoration(
        color: ledger ? LedgerColors.card : AppColors.surface,
        borderRadius: BorderRadius.circular(ledger ? 6 : 14),
        border: Border.all(
          color: ledger ? LedgerColors.border : AppColors.border,
        ),
      ),
      child: TextField(
        key: const Key('glossary-search-field'),
        controller: _searchController,
        onChanged: (value) {
          setState(() => _query = value);
          _scheduleUrlSync(value);
        },
        style: TextStyle(
          fontFamily: ledger ? LedgerColors.fontSans : null,
          fontSize: 14.5,
          color: ledger ? LedgerColors.ink : AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Search DNSH, Scope 3, materiality…',
          hintStyle: TextStyle(
            fontFamily: ledger ? LedgerColors.fontSans : null,
            fontSize: 14.5,
            color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
            size: 20,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close,
                    color: ledger ? LedgerColors.inkSoft : AppColors.inkSoft,
                    size: 18,
                  ),
                  onPressed: () {
                    AppFeedback.tap();
                    _searchController.clear();
                    setState(() => _query = '');
                    _scheduleUrlSync('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool ledger) {
    final favoriteCount = ProgressStore.instance.favoriteTermKeys.length;
    // Plain Material chips on native-style layouts (identical to the app);
    // "The Ledger" gets flat, hairline chips in its own tokens.
    ChoiceChip chip({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Widget? avatar,
    }) => ChoiceChip(
      key: key,
      avatar: avatar,
      showCheckmark: avatar == null,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: ledger ? LedgerColors.tealSoft : null,
      backgroundColor: ledger ? LedgerColors.card : null,
      side: ledger ? const BorderSide(color: LedgerColors.border) : null,
      shape: ledger
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))
          : null,
      labelStyle: ledger
          ? TextStyle(
              fontFamily: LedgerColors.fontSans,
              fontSize: 12.5,
              color: selected ? LedgerColors.teal : LedgerColors.inkSoft,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            )
          : null,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip(
          key: const Key('glossary-filter-all'),
          label: 'All terms',
          selected: !_onlyFavorites,
          onTap: () => setState(() => _onlyFavorites = false),
        ),
        chip(
          key: const Key('glossary-filter-favorites'),
          avatar: Icon(
            Icons.star_rounded,
            size: 16,
            color: ledger ? LedgerColors.goldDeep : null,
          ),
          label: 'Favourites ($favoriteCount)',
          selected: _onlyFavorites,
          onTap: () => setState(() => _onlyFavorites = true),
        ),
      ],
    );
  }

  /// Centres [child] in the space left under the header, and lets it scroll
  /// when that space is too short for it (a landscape phone, large text).
  Widget _centeredScroll(Widget child) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  Widget _buildEmptyState(bool ledger) {
    final soft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    if (_onlyFavorites && _query.trim().isEmpty) {
      return _centeredScroll(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No favourites yet. Tap the star on a term to keep it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontSans : null,
              fontSize: 14,
              color: soft,
            ),
          ),
        ),
      );
    }
    return _centeredScroll(
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: soft, size: 36),
            const SizedBox(height: 10),
            Text(
              'No terms match "$_query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ledger ? LedgerColors.fontSans : null,
                fontSize: 14,
                color: soft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermCard(Term term, bool ledger) {
    final key = _keyFor(term);
    final isExpanded = _expanded.contains(key);
    final cardColor = ledger ? LedgerColors.card : AppColors.surface;
    final borderColor = ledger ? LedgerColors.border : AppColors.border;
    final radius = ledger ? 6.0 : 16.0;
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final inkSoft = ledger ? LedgerColors.inkSoft : AppColors.inkSoft;
    final moduleColor = ledger ? LedgerColors.teal : AppColors.tealDeep;
    final sansFont = ledger ? LedgerColors.fontSans : null;
    final monoFont = ledger ? LedgerColors.fontMono : 'monospace';
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        key: Key('glossary-term-${term.term}'),
        borderRadius: BorderRadius.circular(radius),
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
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
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
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 7),
                              decoration: BoxDecoration(
                                // A handful of foundational terms (e.g. "ESG"
                                // itself, "Stakeholder") deliberately carry no
                                // single E/S/G/Finance/Regulation theme — a
                                // neutral dot keeps every row visually
                                // consistent instead of some rows silently
                                // missing one.
                                color: term.theme?.color ?? inkSoft,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                term.term,
                                style: TextStyle(
                                  fontFamily: sansFont,
                                  fontWeight: ledger
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                  fontSize: 15.5,
                                  color: ink,
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
                                style: TextStyle(
                                  fontFamily: monoFont,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: moduleColor,
                                ),
                              ),
                            ),
                            if (term.theme != null) ...[
                              Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: inkSoft,
                                ),
                              ),
                              Text(
                                term.theme!.label,
                                style: TextStyle(
                                  fontFamily: monoFont,
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
                  IconButton(
                    key: Key('glossary-favorite-${term.term}'),
                    tooltip: ProgressStore.instance.isFavorite(key)
                        ? 'Remove from favourites'
                        : 'Add to favourites',
                    icon: Icon(
                      ProgressStore.instance.isFavorite(key)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: ProgressStore.instance.isFavorite(key)
                          ? (ledger ? LedgerColors.goldDeep : AppColors.amber)
                          : inkSoft,
                    ),
                    onPressed: () {
                      AppFeedback.tap();
                      ProgressStore.instance.toggleFavorite(key);
                      setState(() {});
                    },
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: inkSoft,
                      size: 22,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDetail(term, ledger),
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

  /// The term named at the start of "Don't confuse with" ("DNSH — the ...")
  /// when it exists in the glossary, so the learner can jump straight to it.
  Term? _relatedTerm(Term term) {
    final raw = term.dontConfuseWith;
    if (raw == null) return null;
    final i = raw.indexOf(' — ');
    if (i <= 0) return null;
    return MockData.relatedTermNamed(raw.substring(0, i), except: term);
  }

  void _openTerm(Term term) {
    AppFeedback.tap();
    setState(() {
      _onlyFavorites = false;
      _searchController.text = term.term;
      _query = term.term;
      _expanded.add(_keyFor(term));
    });
    _scheduleUrlSync(term.term);
    // The previous term's list position would otherwise leave the new card
    // half scrolled out of view.
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  Widget _buildDetail(Term term, bool ledger) {
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    final teal = ledger ? LedgerColors.teal : AppColors.tealDeep;
    final gold = ledger ? LedgerColors.goldDeep : AppColors.amberDeep;
    final related = _relatedTerm(term);
    // On web the share sheet downloads the image where the browser cannot
    // share files, so its icon says "image" rather than the phone share
    // glyph (same choice the app makes).
    final actions = Wrap(
      spacing: 4,
      children: [
        if (related != null)
          TextButton.icon(
            key: Key('glossary-related-${term.term}'),
            onPressed: () => _openTerm(related),
            icon: const Icon(Icons.compare_arrows, size: 18),
            label: Text('Open ${related.term}'),
            style: ledger
                ? TextButton.styleFrom(foregroundColor: LedgerColors.teal)
                : null,
          ),
        TextButton.icon(
          key: Key('glossary-share-${term.term}'),
          onPressed: () => shareTermCard(context, term),
          icon: Icon(kIsWeb ? Icons.image_outlined : Icons.ios_share, size: 18),
          label: const Text('Share as image'),
          style: ledger
              ? TextButton.styleFrom(foregroundColor: LedgerColors.teal)
              : null,
        ),
      ],
    );
    if (!term.hasRichFormat) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term.definition,
            style: TextStyle(
              fontFamily: ledger ? LedgerColors.fontSans : null,
              fontSize: 13.5,
              color: ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          actions,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('IN PLAIN ENGLISH', term.plainEnglish!, teal, ledger),
        if (term.whyItMatters != null) ...[
          const SizedBox(height: 10),
          _section('WHY IT MATTERS', term.whyItMatters!, teal, ledger),
        ],
        if (term.example != null) ...[
          const SizedBox(height: 10),
          _section('EXAMPLE', term.example!, teal, ledger),
        ],
        if (term.dontConfuseWith != null) ...[
          const SizedBox(height: 10),
          _section("DON'T CONFUSE WITH", term.dontConfuseWith!, gold, ledger),
        ],
        const SizedBox(height: 6),
        actions,
      ],
    );
  }

  Widget _section(String label, String body, Color labelColor, bool ledger) {
    final ink = ledger ? LedgerColors.ink : AppColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: ledger ? LedgerColors.fontMono : 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: TextStyle(
            fontFamily: ledger ? LedgerColors.fontSans : null,
            fontSize: 13.5,
            color: ink,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
