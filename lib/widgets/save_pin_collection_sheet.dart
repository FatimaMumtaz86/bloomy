import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

Future<void> showSavePinCollectionSheet({
  required BuildContext context,
  required String pinId,
  required String userId,
  required bool wasSaved,
}) async {
  final pinProvider = context.read<PinProvider>();
  await pinProvider.loadSavedPinCollections(userId);

  final initialCollection = pinProvider.savedPinCollectionFor(pinId);
  final Set<String> localCollections =
      <String>{...pinProvider.savedPinCollections, initialCollection};
  String selectedCollection = initialCollection;
  String newCollectionDraft = '';

  if (!context.mounted) {
    return;
  }

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
                    wasSaved ? 'Manage saved pin' : 'Save pin to collection',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (wasSaved)
                        TextButton(
                          onPressed: () async {
                            await pinProvider.unsavePin(pinId, userId);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from saved pins'),
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
                          final trimmedNewCollection =
                              newCollectionDraft.trim();
                          if (trimmedNewCollection.isNotEmpty) {
                            selectedCollection = trimmedNewCollection;
                          }

                          if (wasSaved) {
                            await pinProvider.updateSavedPinCollection(
                              pinId: pinId,
                              userId: userId,
                              collectionName: selectedCollection,
                            );
                          } else {
                            await pinProvider.savePin(
                              pinId,
                              userId,
                              collectionName: selectedCollection,
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
                                    ? 'Moved to "$selectedCollection"'
                                    : 'Saved to "$selectedCollection"',
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
