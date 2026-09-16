import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/lead_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/leads/bloc/lead_bloc.dart';
import 'features/leads/screens/lead_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => LeadRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(context.read<AuthRepository>())
              ..add(AuthSubscriptionRequested()),
          ),
          BlocProvider(
            create: (context) => LeadBloc(context.read<LeadRepository>()),
          ),
        ],
        child: MaterialApp(
          title: 'Enterprise CRM',
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
          ),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state.status == AuthStatus.authenticated) {
                return const LeadListScreen();
              }
              if (state.status == AuthStatus.unauthenticated) {
                return const LoginScreen();
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            },
          ),
        ),
      ),
    );
  }
}