import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_item.dart';
import '../services/download_queue_manager.dart';
import 'app_providers.dart';

final downloadQueueManagerProvider =
    ChangeNotifierProvider<DownloadQueueManager>((ref) {
  return DownloadQueueManager(ref.read(storageServiceProvider));
});

final downloadQueueProvider = Provider<List<DownloadItem>>((ref) {
  return ref.watch(downloadQueueManagerProvider).state.queue;
});

final hasQueueItemsProvider = Provider<bool>((ref) {
  return !ref.watch(downloadQueueManagerProvider).state.isEmpty;
});
