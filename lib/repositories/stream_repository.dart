import 'package:livestreamdeemo/services/cloudflare_service.dart';

class StreamRepository {
  final CloudflareService cloudflareService;

  StreamRepository({required this.cloudflareService});

  Future<String> getPlaybackUrl(String uid, String domain) async {
    return await cloudflareService.getPlaybackUrl(uid, domain);
  }
}
