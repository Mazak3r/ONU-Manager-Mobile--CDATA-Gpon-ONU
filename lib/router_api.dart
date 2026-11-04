import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────

class WifiNetwork {
  final String band;
  final String ssid;
  final String password;
  final bool enabled;
  final bool hidden;
  final int encryption;

  WifiNetwork({
    required this.band,
    required this.ssid,
    required this.password,
    required this.enabled,
    required this.hidden,
    required this.encryption,
  });

  @override
  String toString() =>
      '[$band] $ssid  pass="$password"  enabled=$enabled  hidden=$hidden';
}

class TrafficStats {
  final String ifname;
  final double upRate;   // raw value from router (100 bytes/sec units)
  final double downRate;

  TrafficStats({
    required this.ifname,
    required this.upRate,
    required this.downRate,
  });

  /// Raw × 10 gives kbps (matches the router's own UI).
  double get upKbps => upRate * 10.0;
  double get downKbps => downRate * 10.0;

  /// Raw ÷ 100 gives Mbps.
  double get upMbps => upRate / 100.0;
  double get downMbps => downRate / 100.0;

  @override
  String toString() =>
      '$ifname ↑${upKbps.toStringAsFixed(2)} kbps ↓${downKbps.toStringAsFixed(2)} kbps';
}

class ConnectionInfo {
  final int wlanNum;
  final int wlanLink;
  final int lanNum;
  final int lanLink;
  final int internetLink;

  ConnectionInfo({
    required this.wlanNum,
    required this.wlanLink,
    required this.lanNum,
    required this.lanLink,
    required this.internetLink,
  });
}

class PonInfo {
  final String ponMode;
  final int onuState;
  final int ponState;
  final String ponMac;
  final String gponSn;
  final String loid;

  final double rxPower;
  final double txPower;
  final double temp;
  final double voltage;
  final double biasCurrent;

  PonInfo({
    required this.ponMode,
    required this.onuState,
    required this.ponState,
    required this.ponMac,
    required this.gponSn,
    required this.loid,
    required this.rxPower,
    required this.txPower,
    required this.temp,
    required this.voltage,
    required this.biasCurrent,
  });

  static double _num(dynamic v) {
    if (v == null) return 0;
    final s = v.toString();
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
    if (match == null) return 0;
    return double.tryParse(match.group(0)!) ?? 0;
  }

  factory PonInfo.fromJson(Map<String, dynamic> j) {
    return PonInfo(
      ponMode: j['pon_mode'] ?? '?',
      onuState: j['onu_state'] ?? 0,
      ponState: j['ponState'] ?? 0,
      ponMac: j['pon_mac'] ?? '',
      gponSn: j['gpon_sn'] ?? '',
      loid: j['loid'] ?? '',
      rxPower: _num(j['rxPower']),
      txPower: _num(j['txPower']),
      temp: _num(j['temp']),
      voltage: _num(j['voltage']),
      biasCurrent: _num(j['biasCurrent']),
    );
  }

  String get rxHealth {
    if (rxPower > -8) return 'too hot';
    if (rxPower >= -27) return 'good';
    if (rxPower >= -30) return 'marginal';
    return 'weak';
  }

  int get rxColor {
    if (rxPower > -8) return 0xFFFF9800;
    if (rxPower >= -27) return 0xFF4CAF50;
    if (rxPower >= -30) return 0xFFFFC107;
    return 0xFFF44336;
  }
}

class ConnectedDevice {
  final String name;
  final String ip;
  final String mac;
  final String speed;
  final String band;

  ConnectedDevice({
    required this.name,
    required this.ip,
    required this.mac,
    required this.speed,
    required this.band,
  });

  static String _clean(String s) {
    return s
        .replaceAll(RegExp(r'[\x00-\x1F\uFFFD]+'), '')
        .replaceAll(RegExp(r'[\uFFFD]+$'), '')
        .trim();
  }

  factory ConnectedDevice.fromJson(String band, Map<String, dynamic> j) {
    final rawName = j['wifi_terminal_name'] ??
        j['terminal_name'] ??
        j['name'] ??
        '';
    final rawIp = j['wifi_terminal_ip'] ?? j['terminal_ip'] ?? j['ip'] ?? '';
    final rawMac =
        j['wifi_terminal_mac'] ?? j['terminal_mac'] ?? j['mac'] ?? '';
    final rawSpeed =
        j['wifi_terminal_speed'] ?? j['terminal_speed'] ?? j['speed'] ?? '';

    return ConnectedDevice(
      name: _clean(rawName.toString()),
      ip: rawIp.toString(),
      mac: rawMac.toString(),
      speed: rawSpeed.toString(),
      band: band,
    );
  }

  @override
  String toString() =>
      '[$band] ${name.isEmpty ? "(no name)" : name}  $ip  $mac  $speed';
}

// ─────────────────────────────────────────────────────────────
//  Router API client
// ─────────────────────────────────────────────────────────────

class RouterApi {
  final String host;
  String? _token;
  String? _lastUser;
  String? _lastPass;
  Map<String, dynamic>? _lastWlanConfig;

  RouterApi({this.host = '192.168.101.1'});

  Uri _uri(String path) => Uri.parse('http://$host$path');

  String _md5(String s) => md5.convert(utf8.encode(s)).toString();

  // GET: no Content-Type (Boa rejects GETs that include it)
  Map<String, String> get _getHeaders => {
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'http://$host/mobile.html',
        'Origin': 'http://$host',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (_token != null) 'Authorization': _token!,
      };

  // POST: includes Content-Type
  Map<String, String> get _postHeaders => {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
        'Referer': 'http://$host/mobile.html',
        'Origin': 'http://$host',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (_token != null) 'Authorization': _token!,
      };

  String? get token => _token;
  Map<String, dynamic>? get lastWlanConfig => _lastWlanConfig;

  // ── Auth ───────────────────────────────────────────────────

  Future<bool> login(String username, String password) async {
    final body = jsonEncode({
      'module': 'login',
      'username': username,
      'encryPassword': _md5(password),
    });

    // ignore: avoid_print
    print('API_LOGIN → POST ${_uri('/post.json')}  body=$body');

    final headers = Map<String, String>.from(_postHeaders)
      ..['Authorization'] = '';

    final resp = await http.post(
      _uri('/post.json'),
      headers: headers,
      body: body,
    );

    // ignore: avoid_print
    print('API_LOGIN ← status=${resp.statusCode}  body=${resp.body}');

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['code'] != 0) return false;
    _token = data['token'] as String?;
    if (_token != null) {
      _lastUser = username;
      _lastPass = password;
    }
    return _token != null;
  }

  void logout() {
    _token = null;
    _lastUser = null;
    _lastPass = null;
    _lastWlanConfig = null;
  }

  /// Silent re-login if the token expired.
  Future<bool> _ensureAuth() async {
    if (_lastUser == null || _lastPass == null) return false;
    return await login(_lastUser!, _lastPass!);
  }

  // ── Generic module access ──────────────────────────────────

  Future<Map<String, dynamic>> getModule(String module) async {
    Future<Map<String, dynamic>> doGet() async {
      final resp = await http.get(
        _uri('/get.json?module=$module&refresh_login_timer=0'),
        headers: _getHeaders,
      );
      // ignore: avoid_print
      print('API_GET $module ← ${resp.body}');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    var data = await doGet();
    if (data['code'] == 10102) {
      final ok = await _ensureAuth();
      if (ok) data = await doGet();
    }
    return data;
  }

  Future<Map<String, dynamic>> postModule(
      String module, Map<String, dynamic> body) async {
    Future<Map<String, dynamic>> doPost() async {
      final payload = {'module': module, ...body};
      // ignore: avoid_print
      print('API_POST $module → ${jsonEncode(payload)}');
      final resp = await http.post(
        _uri('/post.json'),
        headers: _postHeaders,
        body: jsonEncode(payload),
      );
      // ignore: avoid_print
      print('API_POST $module ← status=${resp.statusCode}  body=${resp.body}');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    var data = await doPost();
    if (data['code'] == 10102) {
      final ok = await _ensureAuth();
      if (ok) data = await doPost();
    }
    return data;
  }

  // ── Wi-Fi: read ────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchRawWlanConfig() async {
    final data = await getModule('wlan_config');
    _lastWlanConfig = data;
    return data;
  }

  Future<List<WifiNetwork>> getWifiNetworks() async {
    final data = await getModule('wlan_config');
    _lastWlanConfig = data;
    final wlan = data['wlan'] as Map<String, dynamic>? ?? {};
    final out = <WifiNetwork>[];

    for (final band in wlan.keys) {
      final bandObj = wlan[band] as Map<String, dynamic>? ?? {};
      final ssids = (bandObj['SSID'] as List?) ?? [];
      for (final s in ssids) {
        final m = s as Map<String, dynamic>;
        out.add(WifiNetwork(
          band: band,
          ssid: m['ssid'] ?? '',
          password: m['wpa_pre_shared_key'] ?? '',
          enabled: m['ssid_enable'] == 1,
          hidden: m['broadcast_enable'] == 1,
          encryption: m['encryption'] ?? 0,
        ));
      }
    }
    return out;
  }

  // ── Wi-Fi: write ───────────────────────────────────────────

  Future<bool> updateWifiNetwork({
    required String band,
    required int slotIndex,
    String? newSsid,
    String? newPassword,
    bool? enable,
  }) async {
    if (_lastWlanConfig == null) {
      await fetchRawWlanConfig();
    }

    final config =
        jsonDecode(jsonEncode(_lastWlanConfig)) as Map<String, dynamic>;
    final wlan = config['wlan'] as Map<String, dynamic>;
    final bandObj = wlan[band] as Map<String, dynamic>;
    final ssids = bandObj['SSID'] as List;

    final slot = ssids[slotIndex] as Map<String, dynamic>;
    if (newSsid != null) slot['ssid'] = newSsid;
    if (newPassword != null) slot['wpa_pre_shared_key'] = newPassword;
    if (enable != null) slot['ssid_enable'] = enable ? 1 : 0;

    config.remove('no_wlan_wpa3');

    final payload = {'module': 'wlan_config', ...config};

    // ignore: avoid_print
    print('API_SET_WIFI → POST /post.json  body=${jsonEncode(payload)}');

    final resp = await http.post(
      _uri('/post.json'),
      headers: _postHeaders,
      body: jsonEncode(payload),
    );

    // ignore: avoid_print
    print('API_SET_WIFI ← status=${resp.statusCode}  body=${resp.body}');

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['code'] == 10102) {
      final ok = await _ensureAuth();
      if (ok) return updateWifiNetwork(
        band: band,
        slotIndex: slotIndex,
        newSsid: newSsid,
        newPassword: newPassword,
        enable: enable,
      );
    }
    return data['code'] == 0;
  }

  // ── Live stats ─────────────────────────────────────────────

  Future<List<TrafficStats>> getTrafficStats() async {
    final data = await getModule('dev_statistics');
    final list = (data['statistics'] as List?) ?? [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return TrafficStats(
        ifname: m['ifname'] ?? '?',
        upRate: (m['up_rate'] as num?)?.toDouble() ?? 0,
        downRate: (m['down_rate'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<ConnectionInfo> getConnectionInfo() async {
    final data = await getModule('dev_connect');
    return ConnectionInfo(
      wlanNum: data['wlan_num'] ?? 0,
      wlanLink: data['wlan_link'] ?? 0,
      lanNum: data['lan_num'] ?? 0,
      lanLink: data['lan_link'] ?? 0,
      internetLink: data['internet_link'] ?? 0,
    );
  }

  // ── PON ────────────────────────────────────────────────────

  Future<PonInfo> getPonInfo() async {
    final data = await getModule('pon_info');
    return PonInfo.fromJson(data);
  }

  // ── Connected devices ──────────────────────────────────────

  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final devices = <ConnectedDevice>[];

    try {
      final wifi = await getModule('terminal_conn_inform_wifi');
      for (final band in wifi.keys) {
        if (band == 'code' || band == 'description') continue;
        final list = wifi[band];
        if (list is List) {
          for (final d in list) {
            if (d is Map<String, dynamic>) {
              devices.add(ConnectedDevice.fromJson(band, d));
            }
          }
        }
      }
    } catch (_) {}

    // We don't bother with LAN variants — Boa returns 10102 for them.

    final seen = <String>{};
    final unique = <ConnectedDevice>[];
    for (final d in devices) {
      final key = d.mac.toLowerCase();
      if (key.isEmpty || seen.add(key)) {
        unique.add(d);
      }
    }
    return unique;
  }

  // ── Reboot ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> reboot() async {
    final payload = {'module': 'dev_config', 'reboot': 1};

    // ignore: avoid_print
    print('API_REBOOT → POST /post.json  body=${jsonEncode(payload)}');

    final resp = await http.post(
      _uri('/post.json'),
      headers: _postHeaders,
      body: jsonEncode(payload),
    );

    // ignore: avoid_print
    print('API_REBOOT ← status=${resp.statusCode}  body=${resp.body}');

    if (resp.statusCode != 200) {
      return {'code': -1, 'description': 'HTTP ${resp.statusCode}'};
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
