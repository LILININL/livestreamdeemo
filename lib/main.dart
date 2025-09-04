import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/repositories/stream_repository.dart';
import 'package:livestreamdeemo/screens/live_stream_screen.dart';
import 'package:livestreamdeemo/services/cloudflare_service.dart';

void main() {
  debugPrint('=== MAIN: App Starting ===');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('=== MyApp: build() ===');
    return RepositoryProvider(
      create: (context) {
        debugPrint('MyApp: Creating StreamRepository');
        return StreamRepository(cloudflareService: CloudflareService());
      },
      child: BlocProvider(
        create: (context) {
          debugPrint('MyApp: Creating StreamBloc');
          return StreamBloc(
            streamRepository: RepositoryProvider.of<StreamRepository>(context),
          );
        },
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              debugPrint('=== MyApp: Building LiveStreamScreen ===');
              debugPrint('MyApp: UID: 184f104ea2258e42fdbae145584b603d');
              debugPrint('MyApp: Domain: https://customer-4vig9foexq6jetjm.cloudflarestream.com');
              return const LiveStreamScreen(
                uid: '184f104ea2258e42fdbae145584b603d',
                domain: 'https://customer-4vig9foexq6jetjm.cloudflarestream.com',
              );
            },
          ),
        ),
      ),
    );
  }
}
