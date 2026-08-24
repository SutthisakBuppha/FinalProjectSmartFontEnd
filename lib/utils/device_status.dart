bool isDeviceOnline(
  Map<String, dynamic> device, {
  Duration heartbeatTimeout = const Duration(seconds: 65),
}) {
  final rawHeartbeat = device['last_heartbeat_at']?.toString().trim();
  if (rawHeartbeat != null && rawHeartbeat.isNotEmpty) {
    final heartbeat = DateTime.tryParse(rawHeartbeat);
    if (heartbeat != null) {
      final age = DateTime.now().toUtc().difference(heartbeat.toUtc());
      return !age.isNegative && age <= heartbeatTimeout;
    }
  }

  final status = device['status']?.toString().trim().toLowerCase() ?? '';
  return status == 'online' || status == 'ออนไลน์';
}
