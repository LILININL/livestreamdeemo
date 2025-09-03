import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livestreamdeemo/bloc/stream/stream_bloc.dart';
import 'package:livestreamdeemo/repositories/stream_repository.dart';
import 'package:livestreamdeemo/screens/live_stream_screen.dart';
import 'package:livestreamdeemo/services/cloudflare_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) =>
          StreamRepository(cloudflareService: CloudflareService()),
      child: BlocProvider(
        create: (context) => StreamBloc(context.read<StreamRepository>()),
        child: MaterialApp(
          home: const LiveStreamScreen(
            uid: '184f104ea2258e42fdbae145584b603d',
            domain: 'https://customer-4vig9foexq6jetjm.cloudflarestream.com',
          ),
        ),
      ),
    );
  }
}
