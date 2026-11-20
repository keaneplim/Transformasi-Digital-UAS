import 'package:jelajah_taman/modules/content/content.dart';

/// What a scanned QR code means for the guide (A02, UC-A02-1/2).
sealed class QrScan {
  const QrScan();
}

/// A Jelajah Taman board for a POI in the content.
class QrPoi extends QrScan {
  const QrPoi(this.poi);
  final Poi poi;
}

/// `jelajahtaman://poi/<ID>` with an ID the content doesn't know (old or misprinted board).
class QrUnknownPoi extends QrScan {
  const QrUnknownPoi(this.id);
  final String id;
}

/// Any other QR code (a URL, a payment code, …).
class QrForeign extends QrScan {
  const QrForeign();
}

final _payload =
    RegExp(r'^jelajahtaman://poi/([a-z0-9_-]+)/*$', caseSensitive: false);

/// The POI ID in a board payload, upper-cased (`jelajahtaman://poi/p05/` → `P05`), or null
/// when [raw] is not a Jelajah Taman payload. Surrounding spaces and trailing slashes are
/// tolerated because phone keyboards and QR generators add them.
String? poiIdFromQr(String raw) =>
    _payload.firstMatch(raw.trim())?.group(1)?.toUpperCase();

/// Resolves [raw] against the bundled content, offline (A02: no network needed).
QrScan resolveQr(String raw, ContentRepository content) {
  final id = poiIdFromQr(raw);
  if (id == null) return const QrForeign();
  final poi = content.poiById(id);
  return poi == null ? QrUnknownPoi(id) : QrPoi(poi);
}
