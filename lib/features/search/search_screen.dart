import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';
import '../photo_detail/photo_detail_screen.dart';

/// Full-screen search across photos, locations, and notes.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<Photo> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ref
          .read(photoRepositoryProvider)
          .search(query.trim());
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        context.showSnackBar('Search failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by location, notes, or tags...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_searchController.text == value) {
                    _performSearch(value);
                  }
                });
                setState(() {}); // Update suffix icon
              },
              onSubmitted: _performSearch,
            ),
          ),
        ),
      ),
      body: _buildBody(colorScheme, isDark),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, bool isDark) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search your memories',
              style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Find photos by location, notes, or tags.',
              style: AppTextStyles.body2.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term.',
              style: AppTextStyles.body2.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${_results.length} result${_results.length != 1 ? 's' : ''}',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final photo = _results[index];
              return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PhotoDetailScreen(
                                photos: List.from(_results),
                                initialIndex: index,
                              ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'photo_${photo.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(photo.filePath),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                    ),
                                  ),
                            ),
                            // Location/note overlay
                            if (photo.locationName != null)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.6),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    photo.locationName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 30 * index),
                    duration: 300.ms,
                  )
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    delay: Duration(milliseconds: 30 * index),
                    duration: 300.ms,
                  );
            },
          ),
        ),
      ],
    );
  }
}
