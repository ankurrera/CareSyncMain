import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Target app environment modes.
enum AppEnvironment { development, staging, production }

/// Environment configuration for the app.
///
/// Loads values from compile-time --dart-define parameters or fallback .env file.
/// Make sure to call `dotenv.load()` in main.dart before using these values.
abstract class EnvConfig {
  static const _appEnv = String.fromEnvironment('APP_ENV');
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _biometricApiUrl = String.fromEnvironment('BIOMETRIC_API_URL');
  static const _fallbackBiometricApiUrl = String.fromEnvironment(
    'FALLBACK_BIOMETRIC_API_URL',
  );
  static const _hfToken = String.fromEnvironment('HF_TOKEN');

  /// Detect active app environment. Defaults to [AppEnvironment.development].
  static AppEnvironment get environment {
    final envName =
        _appEnv.isNotEmpty ? _appEnv : (dotenv.env['APP_ENV'] ?? 'development');
    switch (envName.toLowerCase()) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'development':
      case 'dev':
      default:
        return AppEnvironment.development;
    }
  }

  /// Supabase project URL
  static String get supabaseUrl {
    if (_supabaseUrl.isNotEmpty) return _supabaseUrl;
    return dotenv.env['SUPABASE_URL'] ?? _throwMissingEnv('SUPABASE_URL');
  }

  /// Supabase anonymous key (safe to expose in client)
  static String get supabaseAnonKey {
    if (_supabaseAnonKey.isNotEmpty) return _supabaseAnonKey;
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        _throwMissingEnv('SUPABASE_ANON_KEY');
  }

  /// Base URL for emergency QR codes
  static String get emergencyBaseUrl => '$supabaseUrl/functions/v1/emergency';

  /// Custom Biometric API URL (local python server or deployed endpoint)
  static String get biometricApiUrl {
    if (_biometricApiUrl.isNotEmpty) return _biometricApiUrl;
    return dotenv.env['BIOMETRIC_API_URL'] ?? 'http://localhost:8000';
  }

  /// Fallback Biometric API URL (redundant failover endpoint)
  static String get fallbackBiometricApiUrl {
    if (_fallbackBiometricApiUrl.isNotEmpty) return _fallbackBiometricApiUrl;
    return dotenv.env['FALLBACK_BIOMETRIC_API_URL'] ?? 'http://localhost:8000';
  }

  /// Hugging Face Token for private Space API authentication
  static String? get hfToken {
    if (_hfToken.isNotEmpty) return _hfToken;
    return dotenv.env['HF_TOKEN'];
  }

  /// Helper to throw meaningful error for missing env vars
  static String _throwMissingEnv(String key) {
    throw Exception(
      'Missing environment variable: $key\n'
      'Please ensure you have a .env file with all required variables or pass them as --dart-define.\n'
      'See .env.example for reference.',
    );
  }
}
