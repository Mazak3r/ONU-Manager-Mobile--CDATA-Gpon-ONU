import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router_api.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  runApp(const MaterialApp(
    home: RouterApp(),
    debugShowCheckedModeBanner: false,
  ));
}

// ─────────────────────────────────────────────────────────────
//  Root — owns API + polls + nav
// ─────────────────────────────────────────────────────────────

class RouterApp extends StatefulWidget {
  const RouterApp({super.key});

  @override
  State<RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<RouterApp> {
  final _api = RouterApi();

  // Connection state
  bool _connecting = false;
  bool _connected = false;
  String _connectError = '';

  // Live data
  List<TrafficStats> _stats = [];
  ConnectionInfo? _conn;
  PonInfo? _pon;
  List<ConnectedDevice> _devices = [];
  List<WifiNetwork> _wifiNetworks = [];

  Timer? _pollTimer;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tryAutoConnect();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryAutoConnect() async {
    setState(() {
      _connecting = true;
      _connectError = '';
    });

    // Load saved creds or use defaults
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('user') ?? 'adminisp';
    final pass = prefs.getString('pass') ?? 'admin1234';

    try {
      final ok = await _api.login(user, pass);
      if (ok) {
        await _onConnected(user, pass);
        return;
      }
    } catch (_) {}

    setState(() {
      _connecting = false;
      _connectError = '';
    });
  }

  Future<void> _connectWith(String user, String pass) async {
    setState(() {
      _connecting = true;
      _connectError = '';
    });

    try {
      final ok = await _api.login(user, pass);
      if (!ok) {
        setState(() {
          _connecting = false;
          _connectError = 'Login failed. Check username and password.';
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', user);
      await prefs.setString('pass', pass);
      await _onConnected(user, pass);
    } catch (e) {
      setState(() {
        _connecting = false;
        _connectError = 'Could not reach router: $e';
      });
    }
  }

  Future<void> _onConnected(String user, String pass) async {
    // Warm up data
    try {
      _wifiNetworks = await _api.getWifiNetworks();
    } catch (_) {}
    try {
      _pon = await _api.getPonInfo();
    } catch (_) {}
    try {
      _devices = await _api.getConnectedDevices();
    } catch (_) {}
    try {
      _stats = await _api.getTrafficStats();
      _conn = await _api.getConnectionInfo();
    } catch (_) {}

    setState(() {
      _connecting = false;
      _connected = true;
      _tabIndex = 0;
    });

    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final s = await _api.getTrafficStats();
        final c = await _api.getConnectionInfo();
        final p = await _api.getPonInfo();
        final d = await _api.getConnectedDevices();
        if (!mounted) return;
        setState(() {
          _stats = s;
          _conn = c;
          _pon = p;
          _devices = d;
        });
      } catch (_) {}
    });
  }

  Future<void> _disconnect() async {
    _pollTimer?.cancel();
    _api.logout();
    setState(() {
      _connected = false;
      _stats = [];
      _conn = null;
      _pon = null;
      _devices = [];
      _wifiNetworks = [];
    });
  }

  Future<void> _reboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Reboot router?'),
        content: const Text(
          'The router will restart. Wi-Fi will drop for about 60–90 seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
            child: const Text('Reboot'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.reboot();
    if (!mounted) return;
    _pollTimer?.cancel();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _RebootDialog(),
    );
    await _disconnect();
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return ConnectScreen(
        connecting: _connecting,
        error: _connectError,
        onConnect: _connectWith,
      );
    }

    final tabs = [
      DashboardTab(
        stats: _stats,
        conn: _conn,
        pon: _pon,
        devices: _devices,
        wifiNetworks: _wifiNetworks.where((n) => n.enabled).toList(),
        onEditWifi: _editWifi,
      ),
      DevicesTab(devices: _devices),
      WifiTab(
        networks: _wifiNetworks.where((n) => n.enabled).toList(),
        onEdit: _editWifi,
      ),
      MoreTab(onReboot: _reboot, onDisconnect: _disconnect),
    ];

    return Scaffold(
      extendBody: true,
      body: GradientScaffold(
        child: IndexedStack(index: _tabIndex, children: tabs),
      ),
      bottomNavigationBar: _GlassNavBar(
        index: _tabIndex,
        onChanged: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Future<void> _editWifi(WifiNetwork net) async {
    final ssidCtrl = TextEditingController(text: net.ssid);
    final passCtrl = TextEditingController(text: net.password);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text('Edit ${net.ssid}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssidCtrl,
              decoration: const InputDecoration(labelText: 'SSID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return;

    final bandNets = _wifiNetworks.where((n) => n.band == net.band).toList();
    final slotIndex = bandNets.indexWhere((n) => n.ssid == net.ssid);

    final ok = await _api.updateWifiNetwork(
      band: net.band,
      slotIndex: slotIndex,
      newSsid: ssidCtrl.text,
      newPassword: passCtrl.text,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved ✓' : 'Router rejected the change'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (ok) {
      final fresh = await _api.getWifiNetworks();
      setState(() => _wifiNetworks = fresh);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Connect screen
// ─────────────────────────────────────────────────────────────

class ConnectScreen extends StatelessWidget {
  final bool connecting;
  final String error;
  final void Function(String user, String pass) onConnect;

  const ConnectScreen({
    super.key,
    required this.connecting,
    required this.error,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffold(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppGradients.purplePink,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadow.soft,
                ),
                child: const Icon(
                  Icons.router_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const Gap(28),
              const Text('Router', style: AppText.h1, textAlign: TextAlign.center),
              const Gap(8),
              const Text(
                'Connect to your router to monitor\nsignal, devices, and traffic.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const Gap(40),
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: connecting ? 'Connecting…' : 'Connect to Router',
                  icon: Icons.wifi_rounded,
                  loading: connecting,
                  onPressed: connecting ? null : () => onConnect('adminisp', 'admin1234'),
                ),
              ),
              const Gap(12),
              TextButton(
                onPressed: connecting
                    ? null
                    : () => _showCredsSheet(context),
                child: const Text(
                  'Use different credentials',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (error.isNotEmpty) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bad.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: AppColors.bad,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const Spacer(flex: 4),
              const Text('Wi-Fi must be connected', style: AppText.small),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }

  void _showCredsSheet(BuildContext context) {
    final userCtrl = TextEditingController(text: 'adminisp');
    final passCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Router credentials', style: AppText.h2),
              const Gap(16),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(20),
              PillButton(
                label: 'Connect',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  onConnect(userCtrl.text, passCtrl.text);
                },
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dashboard tab
// ─────────────────────────────────────────────────────────────

class DashboardTab extends StatelessWidget {
  final List<TrafficStats> stats;
  final ConnectionInfo? conn;
  final PonInfo? pon;
  final List<ConnectedDevice> devices;
  final List<WifiNetwork> wifiNetworks;
  final void Function(WifiNetwork) onEditWifi;

  const DashboardTab({
    super.key,
    required this.stats,
    required this.conn,
    required this.pon,
    required this.devices,
    required this.wifiNetworks,
    required this.onEditWifi,
  });

  @override
  Widget build(BuildContext context) {
    final downKbps = stats.isEmpty ? 0.0 : stats.first.downKbps;
    final upKbps = stats.isEmpty ? 0.0 : stats.first.upKbps;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(
                child: Text('Dashboard', style: AppText.h1),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  conn?.internetLink == 1
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  color: conn?.internetLink == 1
                      ? AppColors.primary
                      : AppColors.bad,
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            conn?.internetLink == 1
                ? 'Connected · Internet online'
                : 'Connected · No internet',
            style: AppText.body,
          ),
          const Gap(20),

          // ── HERO: Live traffic ───────────────────────────
          SoftCard(
            padding: const EdgeInsets.all(22),
            gradient: AppGradients.purplePink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.speed_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'LIVE TRAFFIC',
                      style: AppText.tiny.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Gap(18),
                Row(
                  children: [
                    Expanded(
                      child: _TrafficBig(
                        icon: Icons.south_rounded,
                        label: 'Download',
                        value: downKbps,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.white.withOpacity(0.25),
                    ),
                    Expanded(
                      child: _TrafficBig(
                        icon: Icons.north_rounded,
                        label: 'Upload',
                        value: upKbps,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── STAT GRID ─────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              StatTile(
                value: pon != null ? pon!.rxPower.toStringAsFixed(1) : '—',
                unit: 'dBm',
                label: 'RX signal${pon != null ? " · ${pon!.rxHealth}" : ""}',
                accent: pon != null ? Color(pon!.rxColor) : AppColors.primary,
                icon: Icons.signal_cellular_alt_rounded,
                gradient: pon != null && pon!.rxHealth == 'good'
                    ? AppGradients.blueMint
                    : null,
              ),
              StatTile(
                value: devices.length.toString(),
                unit: 'devices',
                label: 'Connected',
                accent: AppColors.primary,
                icon: Icons.devices_rounded,
              ),
              StatTile(
                value: pon != null ? pon!.txPower.toStringAsFixed(1) : '—',
                unit: 'dBm',
                label: 'TX power',
                accent: AppColors.blue,
                icon: Icons.podcasts_rounded,
              ),
              StatTile(
                value: pon != null ? pon!.temp.toStringAsFixed(0) : '—',
                unit: '°C',
                label: 'Module temp',
                accent: AppColors.pink,
                icon: Icons.thermostat_rounded,
              ),
            ],
          ),
          const Gap(24),

          // ── ENABLED SSIDs ─────────────────────────────────
          if (wifiNetworks.isNotEmpty) ...[
            const SectionHeader(title: 'Enabled Wi-Fi'),
            const Gap(10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: wifiNetworks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final n = wifiNetworks[i];
                  return _SsidCard(
                    network: n,
                    gradient: i.isEven
                        ? AppGradients.purplePink
                        : AppGradients.blueMint,
                    onTap: () => onEditWifi(n),
                  );
                },
              ),
            ),
            const Gap(24),
          ],

          // ── DEVICE PREVIEW ────────────────────────────────
          if (devices.isNotEmpty) ...[
            const SectionHeader(title: 'Recently connected'),
            const Gap(10),
            ...devices.take(3).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DeviceRow(device: d),
                )),
          ],
        ],
      ),
    );
  }
}

class _TrafficBig extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;

  const _TrafficBig({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final mbps = value / 1000.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.85)),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppText.tiny.copyWith(
                color: color.withOpacity(0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Gap(6),
        AnimatedNumber(
          value: mbps,
          decimals: 2,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        Text(
          'Mbps',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SsidCard extends StatelessWidget {
  final WifiNetwork network;
  final Gradient gradient;
  final VoidCallback onTap;

  const _SsidCard({
    required this.network,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    network.band,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.wifi_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.85),
                ),
              ],
            ),
            const Spacer(),
            Text(
              network.ssid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Gap(3),
            Text(
              'pass: ${network.password}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final ConnectedDevice device;

  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cardMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.devices_other_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isEmpty ? '(no name)' : device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3,
                ),
                const Gap(2),
                Text(
                  '${device.ip} · ${device.mac}',
                  style: AppText.tiny,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BandChip.forBand(device.band),
              const Gap(4),
              Text(
                device.speed,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ok,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Devices tab
// ─────────────────────────────────────────────────────────────

class DevicesTab extends StatelessWidget {
  final List<ConnectedDevice> devices;

  const DevicesTab({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Devices', style: AppText.h1),
          const Gap(6),
          Text(
            '${devices.length} on your network',
            style: AppText.body,
          ),
          const Gap(20),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No devices connected', style: AppText.body),
              ),
            )
          else
            ...devices.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeviceRow(device: d),
                )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Wi-Fi tab
// ─────────────────────────────────────────────────────────────

class WifiTab extends StatelessWidget {
  final List<WifiNetwork> networks;
  final void Function(WifiNetwork) onEdit;

  const WifiTab({
    super.key,
    required this.networks,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Wi-Fi', style: AppText.h1),
          const Gap(6),
          Text(
            '${networks.length} enabled networks',
            style: AppText.body,
          ),
          const Gap(20),
          ...networks.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => onEdit(n),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: n.band == '5G'
                              ? AppGradients.purplePink
                              : AppGradients.blueMint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.wifi_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.ssid, style: AppText.h3),
                            const Gap(2),
                            Text(
                              'pass: ${n.password}',
                              style: AppText.small,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  More tab
// ─────────────────────────────────────────────────────────────

class MoreTab extends StatelessWidget {
  final VoidCallback onReboot;
  final VoidCallback onDisconnect;

  const MoreTab({
    super.key,
    required this.onReboot,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('More', style: AppText.h1),
          const Gap(20),
          SoftCard(
            onTap: onReboot,
            child: Row(
              children: [
                const Icon(Icons.power_settings_new_rounded,
                    color: AppColors.bad),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Reboot router', style: AppText.h3),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textLight),
              ],
            ),
          ),
          const Gap(12),
          SoftCard(
            onTap: onDisconnect,
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, color: AppColors.textMid),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Disconnect', style: AppText.h3),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textLight),
              ],
            ),
          ),
          const Gap(24),
          Center(
            child: Text(
              'Router Automation · v1.0',
              style: AppText.small,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Glass bottom nav bar
// ─────────────────────────────────────────────────────────────

class _GlassNavBar extends StatelessWidget {
  final int index;
  final void Function(int) onChanged;

  const _GlassNavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.devices_rounded, 'Devices'),
      (Icons.wifi_rounded, 'Wi-Fi'),
      (Icons.more_horiz_rounded, 'More'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadow.soft,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].$1,
                label: items[i].$2,
                selected: i == index,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primaryButton : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppColors.textMid,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reboot countdown dialog
// ─────────────────────────────────────────────────────────────

class _RebootDialog extends StatefulWidget {
  const _RebootDialog();

  @override
  State<_RebootDialog> createState() => _RebootDialogState();
}

class _RebootDialogState extends State<_RebootDialog> {
  int _remaining = 75;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: const Text('Rebooting'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_remaining',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const Gap(8),
          const Text(
            'The router is restarting.\nWi-Fi will return shortly.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
        ],
      ),
    );
  }
}