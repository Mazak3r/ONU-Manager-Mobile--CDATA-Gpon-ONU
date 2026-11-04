import 'dart:async';
import 'dart:io';

class LanDevice {
  final String ip;
  final String? hostname;
  final List<int> openPorts;

  LanDevice({
    required this.ip,
    this.hostname,
    this.openPorts = const [],
  });

  @override
  String toString() {
    final name = hostname != null && hostname!.isNotEmpty ? ' ($hostname)' : '';
    final ports = openPorts.isEmpty ? '' : '  ports: ${openPorts.join(", ")}';
    return '$ip$name$ports';
  }
}

class LanScanner {
  /// Common ports to probe. If ANY responds, the host is considered alive.
  static const List<int> probePorts = [80, 443, 22, 445, 8080, 53, 8000, 8888];

  /// Scans the /24 subnet containing [selfIp].
  /// Calls [onProgress] for each IP tried, [onFound] when a device is detected.
  static Future<List<LanDevice>> scan({
    required String selfIp,
    Duration timeout = const Duration(milliseconds: 400),
    int concurrency = 40,
    void Function(int done, int total)? onProgress,
    void Function(LanDevice device)? onFound,
  }) async {
    // Derive subnet prefix, e.g. "192.168.101."
    final parts = selfIp.split('.');
    if (parts.length != 4) {
      throw ArgumentError('Invalid IPv4: $selfIp');
    }
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final myLast = int.parse(parts[3]);

    final targets = <int>[
      for (int i = 1; i <= 254; i++)
        if (i != myLast) i,
    ];

    final found = <LanDevice>[];
    int done = 0;
    int index = 0;

    Future<void> worker() async {
      while (true) {
        if (index >= targets.length) return;
        final myIndex = index++;
        final last = targets[myIndex];
        final ip = '$prefix$last';

        final openPorts = <int>[];
        for (final port in probePorts) {
          try {
            final socket = await Socket.connect(
              ip,
              port,
              timeout: timeout,
            );
            socket.destroy();
            openPorts.add(port);
          } catch (_) {
            // port closed / no response
          }
        }

        if (openPorts.isNotEmpty) {
          String? hostname;
          try {
            final result = await InternetAddress(ip).reverse();
            hostname = result.host;
          } catch (_) {}

          final dev = LanDevice(
            ip: ip,
            hostname: hostname,
            openPorts: openPorts,
          );
          found.add(dev);
          onFound?.call(dev);
        }

        done++;
        onProgress?.call(done, targets.length);
      }
    }

    final workers = <Future<void>>[];
    for (int i = 0; i < concurrency; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    found.sort((a, b) {
      final aLast = int.tryParse(a.ip.split('.').last) ?? 0;
      final bLast = int.tryParse(b.ip.split('.').last) ?? 0;
      return aLast.compareTo(bLast);
    });

    return found;
  }

  /// Returns the phone's own LAN IP (e.g. "192.168.101.42").
  static Future<String?> getSelfIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Prefer private ranges
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
