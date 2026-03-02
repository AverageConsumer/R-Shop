import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/services/download_foreground_service.dart';

void main() {
  group('DownloadForegroundService.buildNotificationText', () {
    test('shows complete when both counts are zero', () {
      expect(
        DownloadForegroundService.buildNotificationText(0, 0),
        'Downloads complete',
      );
    });

    test('shows active count only', () {
      expect(
        DownloadForegroundService.buildNotificationText(1, 0),
        'Downloading: 1 active',
      );
    });

    test('shows queued count only', () {
      expect(
        DownloadForegroundService.buildNotificationText(0, 3),
        'Downloading: 3 queued',
      );
    });

    test('shows both active and queued', () {
      expect(
        DownloadForegroundService.buildNotificationText(2, 5),
        'Downloading: 2 active, 5 queued',
      );
    });

    test('shows singular counts correctly', () {
      expect(
        DownloadForegroundService.buildNotificationText(1, 1),
        'Downloading: 1 active, 1 queued',
      );
    });

    test('handles large numbers', () {
      expect(
        DownloadForegroundService.buildNotificationText(10, 40),
        'Downloading: 10 active, 40 queued',
      );
    });
  });
}
