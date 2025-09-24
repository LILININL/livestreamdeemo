import 'package:flutter/foundation.dart';

class CloudflareService {
  Future<String> getPlaybackUrl(String uid, String domain) async {
    debugPrint('=== CloudflareService: getPlaybackUrl START ===');
    debugPrint('CloudflareService: Input UID: $uid');
    debugPrint('CloudflareService: Input Domain: $domain');
    debugPrint('CloudflareService: UID Length: ${uid.length} characters');
    debugPrint('CloudflareService: Domain Length: ${domain.length} characters');

    try {
      // final playbackUrl = '$domain/$uid/manifest/video.m3u8';

      final playbackUrl =
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';
      debugPrint('CloudflareService: Generated playback URL: $playbackUrl');
      debugPrint(
        'CloudflareService: Final URL Length: ${playbackUrl.length} characters',
      );
      debugPrint('CloudflareService: URL Format: HLS (.m3u8)');
      debugPrint('=== CloudflareService: getPlaybackUrl SUCCESS ===');
      return playbackUrl;
    } catch (e) {
      debugPrint('=== CloudflareService: getPlaybackUrl ERROR ===');
      debugPrint('CloudflareService: Error generating playback URL: $e');
      debugPrint('CloudflareService: Error type: ${e.runtimeType}');
      throw Exception('Failed to load stream: $e');
    }
  }
}
