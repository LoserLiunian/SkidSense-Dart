import 'dart:convert';

/// How `new URL(text)` — the WHATWG URL Standard, which the desktop parses
/// an account's base URL with (`accountProblem` in its
/// `src/shared/accounts.ts`) — takes [text].
enum WebUrlKind {
  /// It throws: no scheme, no host where one is needed, a port past 65535,
  /// a host that is no domain or IP address.
  invalid,

  /// It parses, as http or https — in any case (`HTTPS://…`), with or
  /// without the slashes after the colon, an IPv6 address, an
  /// internationalized domain, a port.
  http,

  /// It parses, as another scheme (`ftp:`, `mailto:`, `localhost:8080`).
  other,
}

/// [text] as `new URL(text)` takes it, without a base — so a base URL is
/// held to what the computer holds it to, no more: Dart's [Uri] refuses
/// some addresses the standard takes (`http:host`, a backslash for a
/// slash) and takes some it refuses (`http://999.1.1.1`).
///
/// The parts of UTS #46 that need Unicode's tables (its mappings beyond
/// full-width forms, the bidi rule beyond a label mixing Latin and
/// right-to-left letters, which letters join around a non-joiner) are left
/// out: an address they would refuse is taken here, and the computer
/// refuses it in its own words.
WebUrlKind webUrlKind(String text) {
  // Leading and trailing C0 controls and spaces go; tabs and newlines go
  // from anywhere.
  final input = text.replaceAll(RegExp(r'^[\u0000-\u0020]+|[\u0000-\u0020]+$'), '').replaceAll(RegExp('[\t\n\r]'), '');
  final scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+\-.]*):').firstMatch(input);
  // No scheme, and no base to resolve against.
  if (scheme == null) return WebUrlKind.invalid;
  final name = scheme.group(1)!.toLowerCase();
  final rest = input.substring(scheme.end);
  final parsed = switch (name) {
    'file' => _fileParses(rest),
    // Special: any run of slashes, either way round, before the authority —
    // or none (`http:host`).
    'http' || 'https' || 'ws' || 'wss' || 'ftp' => _authorityParses(
        _until(rest.replaceFirst(RegExp(r'^[/\\]*'), ''), RegExp(r'[/\\?#]')),
        special: true,
      ),
    // Another scheme has an authority only after `//`; else a path.
    _ => !rest.startsWith('//') || _authorityParses(_until(rest.substring(2), RegExp('[/?#]')), special: false),
  };
  if (!parsed) return WebUrlKind.invalid;
  return name == 'http' || name == 'https' ? WebUrlKind.http : WebUrlKind.other;
}

String _until(String text, RegExp end) {
  final at = text.indexOf(end);
  return at < 0 ? text : text.substring(0, at);
}

/// A `file:` URL: a host only after two slashes, and that may be empty.
bool _fileParses(String rest) {
  if (!RegExp(r'^[/\\]{2}').hasMatch(rest)) return true;
  final host = _until(rest.substring(2), RegExp(r'[/\\?#]'));
  // A drive letter (`file://C:/`) is a path, not a host.
  if (host.isEmpty || RegExp(r'^[A-Za-z][:|]$').hasMatch(host)) return true;
  return _hostParses(host, opaque: false);
}

/// The authority: user info up to its last `@`, then a host and a port.
bool _authorityParses(String authority, {required bool special}) {
  final at = authority.lastIndexOf('@');
  final hostPort = at < 0 ? authority : authority.substring(at + 1);
  if (at >= 0 && hostPort.isEmpty) return false;
  // The port starts at the first colon outside an IPv6 address's brackets.
  var inside = false;
  var colon = -1;
  for (var index = 0; index < hostPort.length; index++) {
    final char = hostPort[index];
    if (char == '[') {
      inside = true;
    } else if (char == ']') {
      inside = false;
    } else if (char == ':' && !inside) {
      colon = index;
      break;
    }
  }
  final host = colon < 0 ? hostPort : hostPort.substring(0, colon);
  if (host.isEmpty && (colon >= 0 || special)) return false;
  final port = colon < 0 ? '' : hostPort.substring(colon + 1);
  if (!RegExp(r'^[0-9]*$').hasMatch(port)) return false;
  if (port.isNotEmpty && BigInt.parse(port) > BigInt.from(65535)) return false;
  return host.isEmpty || _hostParses(host, opaque: !special);
}

/// The forbidden host code points: what no host may hold.
final _forbiddenHost = RegExp(r'[\u0000\t\n\r #/:<>?@\[\\\]^|]');

/// And what no domain may hold besides: C0 controls, `%` and DEL.
final _forbiddenDomain = RegExp(r'[\u0000-\u0020#/:<>?@\[\\\]^|%\u007f]');

bool _hostParses(String input, {required bool opaque}) {
  if (input.startsWith('[')) return input.endsWith(']') && _ipv6Parses(input.substring(1, input.length - 1));
  if (opaque) return !_forbiddenHost.hasMatch(input);
  final domain = utf8.decode(_percentDecoded(utf8.encode(input)), allowMalformed: true);
  final ascii = _domainToAscii(domain);
  if (ascii == null || _forbiddenDomain.hasMatch(ascii)) return false;
  return !_endsInNumber(ascii) || _ipv4Parses(ascii);
}

List<int> _percentDecoded(List<int> bytes) {
  int? hex(int byte) => switch (byte) {
        >= 0x30 && <= 0x39 => byte - 0x30,
        >= 0x41 && <= 0x46 => byte - 0x37,
        >= 0x61 && <= 0x66 => byte - 0x57,
        _ => null,
      };
  final out = <int>[];
  for (var index = 0; index < bytes.length; index++) {
    final high = index + 2 < bytes.length ? hex(bytes[index + 1]) : null;
    final low = index + 2 < bytes.length ? hex(bytes[index + 2]) : null;
    if (bytes[index] == 0x25 && high != null && low != null) {
      out.add(high * 16 + low);
      index += 2;
    } else {
      out.add(bytes[index]);
    }
  }
  return out;
}

/// Code points UTS #46 drops: the soft hyphen, the zero-width space, the
/// word joiner, variation selectors, the byte order mark…
bool _ignored(int rune) =>
    rune == 0x00ad ||
    rune == 0x034f ||
    (rune >= 0x180b && rune <= 0x180f) ||
    rune == 0x200b ||
    rune == 0x2060 ||
    rune == 0x2064 ||
    (rune >= 0xfe00 && rune <= 0xfe0f) ||
    rune == 0xfeff ||
    (rune >= 0xe0100 && rune <= 0xe01ef);

/// …and some it refuses: the replacement character and its neighbours,
/// surrogates, private use, noncharacters, tags.
bool _disallowed(int rune) =>
    (rune >= 0x80 && rune <= 0x9f) ||
    (rune >= 0xfff9 && rune <= 0xfffd) ||
    (rune >= 0xd800 && rune <= 0xdfff) ||
    (rune >= 0xe000 && rune <= 0xf8ff) ||
    rune >= 0xf0000 ||
    (rune >= 0xfdd0 && rune <= 0xfdef) ||
    (rune & 0xfffe) == 0xfffe ||
    rune == 0xe0001 ||
    (rune >= 0xe0020 && rune <= 0xe007f);

final _mark = RegExp(r'^\p{M}$', unicode: true);
final _rtlLetter = RegExp(r'^(?=\p{L})[\p{Script=Hebrew}\p{Script=Arabic}\p{Script=Syriac}\p{Script=Thaana}\p{Script=Nko}\p{Script=Samaritan}\p{Script=Mandaic}]$', unicode: true);

/// The domain as UTS #46 ToASCII leaves it (non-transitional, without the
/// STD3 rules or DNS lengths, as the URL Standard asks), null where it
/// fails: an ASCII domain lower-cased; another with its full-width forms and
/// ideographic full stops mapped, each label checked, and each label that
/// is not ASCII — its ASCII checked for forbidden code points first, as it
/// stays in the label's punycode — standing in as an `xn--` one, which
/// holds none and is no number.
String? _domainToAscii(String domain) {
  final plain = !domain.codeUnits.any((unit) => unit > 0x7f) &&
      !domain.split('.').any((label) => label.toLowerCase().startsWith('xn--'));
  if (plain) return domain.toLowerCase();
  final mapped = StringBuffer();
  for (final rune in domain.runes) {
    if (_ignored(rune)) continue;
    if (_disallowed(rune)) return null;
    if (rune >= 0xff01 && rune <= 0xff5e) {
      mapped.writeCharCode(rune - 0xfee0);
    } else if (rune == 0x3002 || rune == 0xff0e || rune == 0xff61) {
      mapped.write('.');
    } else {
      mapped.writeCharCode(rune);
    }
  }
  final labels = <String>[];
  for (final label in mapped.toString().toLowerCase().split('.')) {
    if (label.runes.every((rune) => rune <= 0x7f)) {
      labels.add(label);
      continue;
    }
    // Its ASCII stays as it is in the `xn--` label it becomes, a forbidden
    // code point with it (`例|`, `ü%`): the stand-in would hide it.
    if (_forbiddenDomain.hasMatch(label)) return null;
    if (!_labelValid([for (final rune in label.runes) String.fromCharCode(rune)])) return null;
    labels.add('xn--x');
  }
  return labels.join('.');
}

/// A label that is not ASCII, as UTS #46 checks it — and as the desktop's
/// runtime does (node's URL parser, Ada): at the first zero-width joiner or
/// non-joiner the label is settled, the right-to-left rule and any joiner
/// after it never reached (`xب\u200cب`, `x\u094d\u200dب`, which node takes).
/// Which marks are viramas is in Unicode's tables: any mark stands in for
/// one.
bool _labelValid(List<String> glyphs) {
  // No label starts with a combining mark.
  if (_mark.hasMatch(glyphs.first)) return false;
  for (final (index, glyph) in glyphs.indexed) {
    final before = index == 0 ? null : glyphs[index - 1];
    // A zero-width joiner goes after a virama alone.
    if (glyph == '\u200d') return before != null && _mark.hasMatch(before);
    if (glyph == '\u200c') {
      // A non-joiner after a virama, or with a letter that joins somewhere
      // before it and one somewhere after: never between letters of no
      // script that joins (`a\u200cb`), nor with none on one side
      // (`ب\u200cx`). Which letters join is in Unicode's tables; any that
      // is not ASCII might.
      if (before != null && _mark.hasMatch(before)) return true;
      return glyphs.take(index).any(_mightJoin) && glyphs.skip(index + 1).any(_mightJoin);
    }
  }
  // A label holds Latin letters or right-to-left ones, not both.
  return !(glyphs.any(_rtlLetter.hasMatch) && glyphs.any((glyph) => RegExp('[a-z]').hasMatch(glyph)));
}

bool _mightJoin(String glyph) => glyph.codeUnitAt(0) > 0x7f && glyph != '\u200c' && glyph != '\u200d' && !_mark.hasMatch(glyph);

/// Whether the last label (past a trailing dot) is a number, so the whole
/// must be an IPv4 address.
bool _endsInNumber(String domain) {
  final parts = domain.split('.');
  if (parts.last.isEmpty) {
    if (parts.length == 1) return false;
    parts.removeLast();
  }
  final last = parts.last;
  return RegExp(r'^[0-9]+$').hasMatch(last) || _ipv4Number(last) != null;
}

/// One part of an IPv4 address: decimal, octal after a `0`, hex after `0x`.
BigInt? _ipv4Number(String input) {
  if (input.isEmpty) return null;
  var radix = 10;
  var digits = input;
  if (digits.length >= 2 && (digits.startsWith('0x') || digits.startsWith('0X'))) {
    radix = 16;
    digits = digits.substring(2);
  } else if (digits.length >= 2 && digits.startsWith('0')) {
    radix = 8;
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return BigInt.zero;
  final valid = switch (radix) {
    16 => RegExp(r'^[0-9A-Fa-f]+$'),
    8 => RegExp(r'^[0-7]+$'),
    _ => RegExp(r'^[0-9]+$'),
  };
  return valid.hasMatch(digits) ? BigInt.parse(digits, radix: radix) : null;
}

bool _ipv4Parses(String input) {
  final parts = input.split('.');
  if (parts.last.isEmpty && parts.length > 1) parts.removeLast();
  if (parts.length > 4) return false;
  final numbers = <BigInt>[];
  for (final part in parts) {
    final number = _ipv4Number(part);
    if (number == null) return false;
    numbers.add(number);
  }
  if (numbers.take(numbers.length - 1).any((number) => number > BigInt.from(255))) return false;
  return numbers.last < BigInt.from(256).pow(5 - numbers.length);
}

/// The URL Standard's IPv6 parser, for whether it fails.
bool _ipv6Parses(String input) {
  final units = input.codeUnits;
  int? at(int index) => index < units.length ? units[index] : null;
  bool isHex(int? unit) =>
      unit != null && ((unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x46) || (unit >= 0x61 && unit <= 0x66));
  bool isDigit(int? unit) => unit != null && unit >= 0x30 && unit <= 0x39;
  const colon = 0x3a;
  const dot = 0x2e;
  var piece = 0;
  int? compress;
  var pointer = 0;
  if (at(0) == colon) {
    if (at(1) != colon) return false;
    pointer = 2;
    piece = 1;
    compress = piece;
  }
  while (at(pointer) != null) {
    if (piece == 8) return false;
    if (at(pointer) == colon) {
      if (compress != null) return false;
      pointer++;
      piece++;
      compress = piece;
      continue;
    }
    var length = 0;
    while (length < 4 && isHex(at(pointer))) {
      pointer++;
      length++;
    }
    if (at(pointer) == dot) {
      if (length == 0) return false;
      pointer -= length;
      if (piece > 6) return false;
      var seen = 0;
      while (at(pointer) != null) {
        int? value;
        if (seen > 0) {
          if (at(pointer) == dot && seen < 4) {
            pointer++;
          } else {
            return false;
          }
        }
        if (!isDigit(at(pointer))) return false;
        while (isDigit(at(pointer))) {
          final number = at(pointer)! - 0x30;
          if (value == null) {
            value = number;
          } else if (value == 0) {
            return false;
          } else {
            value = value * 10 + number;
          }
          if (value > 255) return false;
          pointer++;
        }
        seen++;
        if (seen == 2 || seen == 4) piece++;
      }
      return seen == 4 && (compress != null || piece == 8);
    } else if (at(pointer) == colon) {
      pointer++;
      if (at(pointer) == null) return false;
    } else if (at(pointer) != null) {
      return false;
    }
    piece++;
  }
  return compress != null || piece == 8;
}
