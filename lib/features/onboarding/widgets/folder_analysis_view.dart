import 'package:flutter/material.dart';
import '../../../services/rom_folder_service.dart';

class FolderAnalysisView extends StatelessWidget {
  final FolderAnalysisResult result;
  final bool isCreatingFolders;
  final List<String> createdFolders;
  const FolderAnalysisView({
    super.key,
    required this.result,
    this.isCreatingFolders = false,
    this.createdFolders = const [],
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 60, right: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: Colors.redAccent.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'ROM FOLDER SCAN',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: result.folders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final folder = result.folders[index];
                return _FolderRow(
                  folder: folder,
                  isBeingCreated: isCreatingFolders && !folder.exists,
                  wasCreated: createdFolders.contains(folder.folderName),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${result.totalGames} games found',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${result.existingFoldersCount}/${result.folders.length} folders',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final FolderInfo folder;
  final bool isBeingCreated;
  final bool wasCreated;
  const _FolderRow({
    required this.folder,
    this.isBeingCreated = false,
    this.wasCreated = false,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: _buildIcon(),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            folder.folderName,
            style: TextStyle(
              color: folder.exists || wasCreated
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            folder.systemName,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ),
        if (folder.exists || wasCreated)
          Text(
            '${folder.gameCount}',
            style: TextStyle(
              color: folder.accentColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          )
        else if (isBeingCreated)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: folder.accentColor,
            ),
          ),
      ],
    );
  }

  Widget _buildIcon() {
    if (isBeingCreated) {
      return const Icon(Icons.add_circle_outline, color: Colors.orange, size: 18);
    }
    if (wasCreated) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
    }
    if (folder.exists) {
      if (folder.gameCount > 0) {
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      } else {
        return const Icon(Icons.remove_circle_outline,
            color: Colors.orange, size: 18);
      }
    } else {
      return Icon(Icons.radio_button_unchecked,
          color: Colors.grey.shade600, size: 18);
    }
  }
}
