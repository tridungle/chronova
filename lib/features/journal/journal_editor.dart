import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';

/// Bottom sheet for editing journal notes for a photo or a day.
class JournalEditor extends ConsumerStatefulWidget {
  final Photo? photo;
  final String? tripId;
  final DateTime date;

  const JournalEditor({super.key, this.photo, this.tripId, required this.date});

  /// Show the journal editor as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    Photo? photo,
    String? tripId,
    required DateTime date,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => JournalEditor(photo: photo, tripId: tripId, date: date),
    );
  }

  @override
  ConsumerState<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends ConsumerState<JournalEditor> {
  late final TextEditingController _noteController;
  String? _selectedMood;
  final List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.photo?.note ?? '');
    _selectedMood = widget.photo?.mood;
    if (widget.photo?.tags != null) {
      _selectedTags.addAll(widget.photo!.tagList);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: context.screenHeight * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text('Journal Note', style: AppTextStyles.headline3),
                  ),
                  TextButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.date.formattedLong, style: AppTextStyles.caption),

              const SizedBox(height: 20),

              // Mood selector
              Text('How are you feeling?', style: AppTextStyles.subtitle2),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    AppConstants.moods.map((mood) {
                      final isSelected = _selectedMood == mood;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMood = isSelected ? null : mood;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                    : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                isSelected
                                    ? Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    )
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              mood,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 20),

              // Note text field
              Text('Your Note', style: AppTextStyles.subtitle2),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 5,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write about your day, thoughts, memories...',
                ),
              ),

              const SizedBox(height: 20),

              // Tags
              Text('Tags', style: AppTextStyles.subtitle2),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    AppConstants.defaultTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(tag),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        checkmarkColor: colorScheme.primary,
                      );
                    }).toList(),
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    final tags = _selectedTags.join(',');

    // Update photo with note, mood, tags
    if (widget.photo != null) {
      final updated = widget.photo!.copyWith(
        note: note.isEmpty ? null : note,
        mood: _selectedMood,
        tags: tags.isEmpty ? null : tags,
        updatedAt: DateTime.now(),
      );
      await ref.read(photoRepositoryProvider).update(updated);
    }

    // Also save as journal entry
    if (note.isNotEmpty) {
      final entry = JournalEntry(
        id: const Uuid().v4(),
        tripId: widget.tripId,
        photoId: widget.photo?.id,
        date: widget.date,
        content: note,
        mood: _selectedMood,
        tags: tags.isEmpty ? null : tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(journalRepositoryProvider).insert(entry);
    }

    // Refresh data
    ref.invalidate(allPhotosProvider);
    ref.invalidate(timelineDaysProvider);
    ref.invalidate(journalEntriesProvider);

    if (mounted) Navigator.pop(context);
  }
}
