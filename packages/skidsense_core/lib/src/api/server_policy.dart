/// Which backend addresses the phone will talk to.
///
/// `https://` anywhere. Plain `http://` only to this machine or the local
/// network — a development server — because the sign-in token, the refresh
/// cookie and the relay's bearer would otherwise cross the internet in the
/// clear. (The password itself is always sealed, §12; the token is not.)
///
/// The app permits cleartext as a whole (the LAN carrier is `ws://`, sealed
/// by the protocol, to addresses no platform setting can enumerate), so the
/// rule is enforced here, under every request, rather than by the platform.
bool backendAllowed(String base) {
  final uri = Uri.tryParse(base.trim());
  if (uri == null || uri.host.isEmpty) return false;
  return switch (uri.scheme.toLowerCase()) {
    'https' => true,
    'http' => isLocalNetworkHost(uri.host),
    _ => false,
  };
}

/// Loopback, private and link-local addresses, `localhost` and mDNS
/// (`.local`) names; also 100.64.0.0/10, where Tailscale and similar
/// overlays — encrypted themselves — put their peers.
bool isLocalNetworkHost(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) return true;

  final v4 = _ipv4(h);
  if (v4 != null) {
    final [a, b, _, _] = v4;
    return a == 127 ||
        a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  if (h.contains(':')) {
    final address = h.split('%').first; // zone id: fe80::1%en0
    if (address == '::1') return true;
    final first = address.split(':').first;
    final word = first.isEmpty ? 0 : int.tryParse(first, radix: 16);
    if (word == null) return false;
    return (word & 0xfe00) == 0xfc00 || // unique local fc00::/7
        (word & 0xffc0) == 0xfe80; // link-local fe80::/10
  }
  return false;
}

List<int>? _ipv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3 || !RegExp(r'^\d+$').hasMatch(part)) return null;
    final value = int.parse(part);
    if (value > 255) return null;
    octets.add(value);
  }
  return octets;
}
