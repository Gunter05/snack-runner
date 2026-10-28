import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

final userProvider = StateProvider<String>((ref) {
  ref.watch(authProvider);
  final user = Supabase.instance.client.auth.currentUser;
  final meta = user?.userMetadata;
  return (meta?['full_name'] ??
          meta?['name'] ??
          user?.email?.split('@').first ??
          '')
      as String;
});
