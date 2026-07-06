import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WearableService {
  WearableService._privateConstructor();
  static final WearableService instance = WearableService._privateConstructor();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Client configuration parameters (registered on developer portals)
  static const String _redirectUri = 'caresync://oauth-callback';

  // Whoop Auth Config
  static const String _whoopClientId = 'caresync_whoop_client_id';
  static const String _whoopClientSecret = 'caresync_whoop_client_secret';
  static const String _whoopAuthUrl =
      'https://api.prod.whoop.com/oauth/oauth2/auth';
  static const String _whoopTokenUrl =
      'https://api.prod.whoop.com/oauth/oauth2/token';

  // Fitbit Auth Config
  static const String _fitbitClientId = 'caresync_fitbit_client_id';
  static const String _fitbitClientSecret = 'caresync_fitbit_client_secret';
  static const String _fitbitAuthUrl =
      'https://www.fitbit.com/oauth2/authorize';
  static const String _fitbitTokenUrl = 'https://api.fitbit.com/oauth2/token';

  // Garmin Auth Config (uses OAuth 1.0a or OAuth 2.0 Webhooks)
  static const String _garminClientId = 'caresync_garmin_client_id';

  // Launch OAuth Web Page in default system browser
  Future<void> initiateOAuth(String source) async {
    String url = '';
    if (source == 'whoop') {
      url =
          '$_whoopAuthUrl?client_id=$_whoopClientId&redirect_uri=${Uri.encodeComponent(_redirectUri)}&response_type=code&scope=offline%20read:profile%20read:recovery%20read:workout%20read:sleep';
    } else if (source == 'fitbit') {
      url =
          '$_fitbitAuthUrl?client_id=$_fitbitClientId&redirect_uri=${Uri.encodeComponent(_redirectUri)}&response_type=code&scope=activity%20heartrate%20profile%20sleep%20weight';
    } else if (source == 'garmin') {
      // Garmin custom sandbox integration
      url =
          'https://connect.garmin.com/oauth-signin?client_id=$_garminClientId&redirect_uri=${Uri.encodeComponent(_redirectUri)}';
    }

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch authorization web page');
      }
    }
  }

  // Handle OAuth code exchange callback redirect
  Future<bool> handleCallbackRedirect(String source, String code) async {
    String tokenUrl = '';
    String clientId = '';
    String clientSecret = '';

    if (source == 'whoop') {
      tokenUrl = _whoopTokenUrl;
      clientId = _whoopClientId;
      clientSecret = _whoopClientSecret;
    } else if (source == 'fitbit') {
      tokenUrl = _fitbitTokenUrl;
      clientId = _fitbitClientId;
      clientSecret = _fitbitClientSecret;
    } else {
      // Garmin custom sandbox integration fallback
      await _saveTokens(
        source,
        'garmin_sandbox_access_token',
        'garmin_sandbox_refresh_token',
        3600,
      );
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (source == 'fitbit')
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          if (source == 'whoop') 'client_id': clientId,
          if (source == 'whoop') 'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final expiresSeconds = data['expires_in'] as int? ?? 3600;

        await _saveTokens(source, accessToken, refreshToken, expiresSeconds);
        return true;
      }
      return false;
    } catch (e) {
      print('[WEARABLE_SERVICE] OAuth callback exchange error: $e');
      return false;
    }
  }

  // Refreshes the OAuth credentials automatically if expired
  Future<String?> getValidAccessToken(String source) async {
    final expiryStr = await _secureStorage.read(
      key: 'caresync_${source}_token_expiry',
    );
    final accessToken = await _secureStorage.read(
      key: 'caresync_${source}_access_token',
    );
    final refreshToken = await _secureStorage.read(
      key: 'caresync_${source}_refresh_token',
    );

    if (accessToken == null || refreshToken == null) return null;

    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (expiry.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        // Token is still valid
        return accessToken;
      }
    }

    // Token has expired or is expiring soon, trigger refresh exchange
    return await _refreshAccessToken(source, refreshToken);
  }

  Future<String?> _refreshAccessToken(
    String source,
    String refreshToken,
  ) async {
    String tokenUrl = '';
    String clientId = '';
    String clientSecret = '';

    if (source == 'whoop') {
      tokenUrl = _whoopTokenUrl;
      clientId = _whoopClientId;
      clientSecret = _whoopClientSecret;
    } else if (source == 'fitbit') {
      tokenUrl = _fitbitTokenUrl;
      clientId = _fitbitClientId;
      clientSecret = _fitbitClientSecret;
    } else {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (source == 'fitbit')
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          if (source == 'whoop') 'client_id': clientId,
          if (source == 'whoop') 'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access_token'] as String;
        final newRefresh = data['refresh_token'] as String;
        final expiresSeconds = data['expires_in'] as int? ?? 3600;

        await _saveTokens(source, newAccess, newRefresh, expiresSeconds);
        return newAccess;
      }
      return null;
    } catch (e) {
      print('[WEARABLE_SERVICE] OAuth token refresh error: $e');
      return null;
    }
  }

  Future<void> _saveTokens(
    String source,
    String access,
    String refresh,
    int expiresSeconds,
  ) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresSeconds));
    await _secureStorage.write(
      key: 'caresync_${source}_access_token',
      value: access,
    );
    await _secureStorage.write(
      key: 'caresync_${source}_refresh_token',
      value: refresh,
    );
    await _secureStorage.write(
      key: 'caresync_${source}_token_expiry',
      value: expiry.toIso8601String(),
    );
  }

  Future<void> revokeTokens(String source) async {
    await _secureStorage.delete(key: 'caresync_${source}_access_token');
    await _secureStorage.delete(key: 'caresync_${source}_refresh_token');
    await _secureStorage.delete(key: 'caresync_${source}_token_expiry');
  }

  // Fetch Heart Rate data points from Fitbit API
  Future<List<Map<String, dynamic>>> fetchFitbitHeartRate() async {
    final token = await getValidAccessToken('fitbit');
    if (token == null) return [];

    try {
      // Fetch resting heart rate for current day
      final response = await http.get(
        Uri.parse(
          'https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['activities-heart'] as List?;
        if (list == null || list.isEmpty) return [];

        final List<Map<String, dynamic>> results = [];
        for (var item in list) {
          final val = item['value'];
          if (val is Map && val['restingHeartRate'] != null) {
            results.add({
              'value': val['restingHeartRate'].toString(),
              'recorded_at': DateTime.now().toIso8601String(),
              'unit': 'bpm',
              'device_name': 'Fitbit Tracker',
              'duplicate_hash':
                  'fitbit_hr_${item['dateTime']}_${val['restingHeartRate']}',
            });
          }
        }
        return results;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
