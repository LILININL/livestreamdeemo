class CloudflareService {
  Future<String> getPlaybackUrl(String uid, String domain) async {
    try {
      return '$domain/$uid/manifest/video.m3u8';
    } catch (e) {
      throw Exception('Failed to load stream: $e');
    }
  }
}
