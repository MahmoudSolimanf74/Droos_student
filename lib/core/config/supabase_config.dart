import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://tuqjyvauojrxvkttakcz.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR1cWp5dmF1b2pyeHZrdHRha2N6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc4NDQ1NjUsImV4cCI6MjEwMzQyMDU2NX0.xlmxk5cPHRIXDwS5KKc8Sz5UKA05UG7yTS5dZz5Wscg';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
