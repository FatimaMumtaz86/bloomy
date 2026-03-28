import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

enum _PostSaveMode { manual, auto }

String _autoCollectionNameForPost(PostModel post) {
  if (post.isAnonymous) {
    return 'Anonymous Collection';
  }

  final author = post.username?.trim() ?? '';
  if (author.isEmpty) {
    return 'Creator Collection';
  }

  return '$author Collection';
}

Future<void> showSavePostCollectionSheet({
  required BuildContext context,
  required PostModel post,
  required String postId,
}) async {
  final savedProvider = context.read<SavedPostProvider>();
  final wasSaved = savedProvider.isSaved(postId);
  final initialCollection = savedProvider.collectionFor(postId);
  final autoCollectionName = _autoCollectionNameForPost(post);

  final Set<String> localCollections =
      <String>{...savedProvider.collections, initialCollection, autoCollectionName};
  String selectedCollection = initialCollection;
  String newCollectionDraft = '';
  _PostSaveMode selectedMode = initialCollection == autoCollectionName
      ? _PostSaveMode.auto
      : _PostSaveMode.manual;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final orderedCollections = localCollections.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lavender.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wasSaved ? 'Manage saved post' : 'Save post to collection',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Manual Collection'),
                        selected: selectedMode == _PostSaveMode.manual,
                        onSelected: (_) {
                          setModalState(() {
                            selectedMode = _PostSaveMode.manual;
                          });
                        },
                        selectedColor: AppColors.softPink.withValues(alpha: 0.5),
                      ),
                      ChoiceChip(
                        label: const Text('Auto Collection'),
                        selected: selectedMode == _PostSaveMode.auto,
                        onSelected: (_) {
                          setModalState(() {
                            selectedMode = _PostSaveMode.auto;
                          });
                        },
                        selectedColor: AppColors.softPink.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (selectedMode == _PostSaveMode.manual) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: orderedCollections
                          .map(
                            (collection) => ChoiceChip(
                              label: Text(collection),
                              selected: selectedCollection == collection,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedCollection = collection;
                                });
                              },
                              selectedColor:
                                  AppColors.softPink.withValues(alpha: 0.5),
                              labelStyle: TextStyle(
                                color: selectedCollection == collection
                                    ? AppColors.deepPink
                                    : AppColors.textMed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Create new collection',
                        filled: true,
                        fillColor: AppColors.cream,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          newCollectionDraft = value;
                        });
                      },
                      onSubmitted: (_) {
                        final trimmed = newCollectionDraft.trim();
                        if (trimmed.isEmpty) {
                          return;
                        }
                        setModalState(() {
                          localCollections.add(trimmed);
                          selectedCollection = trimmed;
                          newCollectionDraft = '';
                        });
                      },
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Auto will save in "$autoCollectionName"',
                        style: const TextStyle(
                          color: AppColors.textMed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (wasSaved)
                        TextButton(
                          onPressed: () async {
                            await savedProvider.removeSaved(postId);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from saved posts'),
                              ),
                            );
                          },
                          child: const Text(
                            'Unsave',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepPink,
                        ),
                        onPressed: () async {
                          String collectionToSave;
                          if (selectedMode == _PostSaveMode.auto) {
                            collectionToSave = autoCollectionName;
                          } else {
                            final trimmedNewCollection =
                                newCollectionDraft.trim();
                            if (trimmedNewCollection.isNotEmpty) {
                              selectedCollection = trimmedNewCollection;
                            }
                            collectionToSave = selectedCollection;
                          }

                          if (wasSaved) {
                            await savedProvider.updateCollection(
                              postId: postId,
                              collectionName: collectionToSave,
                            );
                          } else {
                            await savedProvider.saveToCollection(
                              postId: postId,
                              collectionName: collectionToSave,
                            );
                          }

                          if (!sheetContext.mounted) {
                            return;
                          }

                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasSaved
                                    ? 'Moved to "$collectionToSave"'
                                    : 'Saved to "$collectionToSave"',
                              ),
                            ),
                          );
                        },
                        child: Text(wasSaved ? 'Update' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
