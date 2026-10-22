import 'dart:math' as math;

/// Approximate coordinates of common transport cities, used to draw routes and
/// to turn a GPS point into "near <city>". Unknown cities simply have no route line.
const Map<String, (double, double)> cityCoords = {
  'delhi': (28.6139, 77.2090),
  'new delhi': (28.6139, 77.2090),
  'gurgaon': (28.4595, 77.0266),
  'gurugram': (28.4595, 77.0266),
  'noida': (28.5355, 77.3910),
  'ghaziabad': (28.6692, 77.4538),
  'faridabad': (28.4089, 77.3178),
  'sonipat': (28.9931, 77.0151),
  'panipat': (29.3909, 76.9635),
  'karnal': (29.6857, 76.9905),
  'ambala': (30.3782, 76.7767),
  'chandigarh': (30.7333, 76.7794),
  'ludhiana': (30.9010, 75.8573),
  'amritsar': (31.6340, 74.8723),
  'jalandhar': (31.3260, 75.5762),
  'jaipur': (26.9124, 75.7873),
  'behror': (27.8880, 76.2870),
  'ajmer': (26.4499, 74.6399),
  'jodhpur': (26.2389, 73.0243),
  'udaipur': (24.5854, 73.7125),
  'kota': (25.2138, 75.8648),
  'bikaner': (28.0229, 73.3119),
  'bhilwara': (25.3407, 74.6313),
  'alwar': (27.5530, 76.6346),
  'agra': (27.1767, 78.0081),
  'mathura': (27.4924, 77.6737),
  'meerut': (28.9845, 77.7064),
  'aligarh': (27.8974, 78.0880),
  'kanpur': (26.4499, 80.3319),
  'lucknow': (26.8467, 80.9462),
  'varanasi': (25.3176, 82.9739),
  'prayagraj': (25.4358, 81.8463),
  'gorakhpur': (26.7606, 83.3732),
  'dehradun': (30.3165, 78.0322),
  'haridwar': (29.9457, 78.1642),
  'ahmedabad': (23.0225, 72.5714),
  'surat': (21.1702, 72.8311),
  'vadodara': (22.3072, 73.1812),
  'rajkot': (22.3039, 70.8022),
  'morbi': (22.8173, 70.8370),
  'indore': (22.7196, 75.8577),
  'bhopal': (23.2599, 77.4126),
  'gwalior': (26.2183, 78.1828),
  'jabalpur': (23.1815, 79.9864),
  'mumbai': (19.0760, 72.8777),
  'pune': (18.5204, 73.8567),
  'nagpur': (21.1458, 79.0882),
  'nashik': (19.9975, 73.7898),
  'aurangabad': (19.8762, 75.3433),
  'hyderabad': (17.3850, 78.4867),
  'bangalore': (12.9716, 77.5946),
  'bengaluru': (12.9716, 77.5946),
  'chennai': (13.0827, 80.2707),
  'kolkata': (22.5726, 88.3639),
  'patna': (25.5941, 85.1376),
  'ranchi': (23.3441, 85.3096),
  'raipur': (21.2514, 81.6296),
  'guwahati': (26.1445, 91.7362),
  'bhubaneswar': (20.2961, 85.8245),
};

(double, double)? coordsOf(String city) => cityCoords[city.trim().toLowerCase()];

double kmBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Road distance is roughly 1.25x the straight line on Indian highways.
int roadKm(double lat1, double lng1, double lat2, double lng2) =>
    (kmBetween(lat1, lng1, lat2, lng2) * 1.25).round();

String _title(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// "Behror ke paas" style label for a GPS point.
String nearLabel(double lat, double lng) {
  String? best;
  var bestKm = double.infinity;
  cityCoords.forEach((name, c) {
    final d = kmBetween(lat, lng, c.$1, c.$2);
    if (d < bestKm) {
      bestKm = d;
      best = name;
    }
  });
  if (best == null) return 'Raste mein';
  if (bestKm < 8) return _title(best!);
  if (bestKm < 60) return '${_title(best!)} ke paas';
  return 'Raste mein';
}

/// Nearest known city name (for posting an empty truck / load).
String nearestCity(double lat, double lng) {
  String best = 'Delhi';
  var bestKm = double.infinity;
  cityCoords.forEach((name, c) {
    final d = kmBetween(lat, lng, c.$1, c.$2);
    if (d < bestKm) {
      bestKm = d;
      best = _title(name);
    }
  });
  return best;
}

/// Progress 0..1 of a trip from [from] to [to] given the truck's position.
double? routeProgress(String from, String to, double? lat, double? lng) {
  final a = coordsOf(from), b = coordsOf(to);
  if (a == null || b == null || lat == null || lng == null) return null;
  final total = kmBetween(a.$1, a.$2, b.$1, b.$2);
  if (total < 1) return null;
  final left = kmBetween(lat, lng, b.$1, b.$2);
  return (1 - left / total).clamp(0.0, 1.0);
}

int? routeKm(String from, String to) {
  final a = coordsOf(from), b = coordsOf(to);
  if (a == null || b == null) return null;
  return roadKm(a.$1, a.$2, b.$1, b.$2);
}

int? kmLeft(String to, double? lat, double? lng) {
  final b = coordsOf(to);
  if (b == null || lat == null || lng == null) return null;
  return roadKm(lat, lng, b.$1, b.$2);
}
