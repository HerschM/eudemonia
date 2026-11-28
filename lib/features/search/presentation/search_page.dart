import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/search/domain/search_index.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Pushes the search page over the navigation shell.
Future<void> openSearchPage(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));

/// How long typing must pause before the results follow the field.
const Duration searchDebounce = Duration(milliseconds: 200);

/// Search across every screen: an autofocused field and one list of matching thoughts (Capture)
/// and synthesis notes (Synthesis), newest first, each labelled with the screen it is on. Choosing
/// a result closes the page and asks the shell to show that item on its screen.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  void _choose(SearchResult result) {
    // The notifiers are taken first: this page is gone once the route has been popped.
    final capture = ref.read(captureFocusRequestProvider.notifier);
    final synthesis = ref.read(synthesisFocusRequestProvider.notifier);
    Navigator.of(context).pop();
    if (result.source == SearchSource.capture) {
      capture.request(result.noteId!);
    } else {
      synthesis.request(result.clusterId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thoughts = ref.watch(recentNotesProvider).value ?? const [];
    final notes = ref.watch(synthesisRepositoryProvider);
    final results = searchThoughtsAndNotes(_query, thoughts: thoughts, notes: notes);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          key: const Key('search_back_button'),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: TextField(
          key: const Key('search_field'),
          controller: _field,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          cursorColor: AppColors.accentCapture,
          decoration: const InputDecoration(
            hintText: 'Search thoughts and notes',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 16),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _query.isEmpty
          ? const _QuietLine(key: Key('search_hint'), text: 'Type a word to search every thought and note.')
          : results.isEmpty
              ? _QuietLine(key: const Key('search_no_match'), text: 'Nothing matches "$_query"')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ResultRow(result: results[i], onTap: () => _choose(results[i])),
                ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  final String text;

  const _QuietLine({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
          ),
        ),
      );
}

class _ResultRow extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultRow({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCapture = result.source == SearchSource.capture;
    final accent = isCapture ? AppColors.accentCapture : AppColors.accentAI;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
      child: InkWell(
        key: Key('search_result_${result.rowId}'),
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppColors.pillRadius),
                    ),
                    child: Text(
                      isCapture ? 'Capture' : 'Synthesis',
                      key: const Key('search_source_label'),
                      style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // A thought's title line already carries its date.
                  if (!isCapture)
                    Expanded(
                      child: Text(
                        formatThoughtTimestamp(result.date),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text.rich(
                _snippetSpan(result),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The snippet in secondary text with the matched ranges in bold primary text.
  TextSpan _snippetSpan(SearchResult r) {
    const base = TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35);
    const bold = TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.35, fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in r.matches) {
      if (m.start > at) spans.add(TextSpan(text: r.snippet.substring(at, m.start), style: base));
      spans.add(TextSpan(text: r.snippet.substring(m.start, m.end), style: bold));
      at = m.end;
    }
    if (at < r.snippet.length) spans.add(TextSpan(text: r.snippet.substring(at), style: base));
    return TextSpan(children: spans, style: base);
  }
}
