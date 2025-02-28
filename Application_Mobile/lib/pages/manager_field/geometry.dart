import 'dart:math';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Algorithme de l'enveloppe convexe (Graham Scan)
List<LatLng> computeConvexHull(List<LatLng> points) {
  if (points.length <= 3) return List.from(points);

  // Trouver le point pivot (celui avec la plus petite latitude, et en cas d'égalité, la plus petite longitude)
  points.sort((a, b) {
    if (a.latitude == b.latitude) {
      return a.longitude.compareTo(b.longitude);
    }
    return a.latitude.compareTo(b.latitude);
  });
  LatLng pivot = points.first;

  // Trie des points par angle par rapport au pivot
  List<LatLng> sortedPoints = List.from(points);
  sortedPoints.removeAt(0);
  sortedPoints.sort((a, b) {
    double angleA = atan2(a.latitude - pivot.latitude, a.longitude - pivot.longitude);
    double angleB = atan2(b.latitude - pivot.latitude, b.longitude - pivot.longitude);
    return angleA.compareTo(angleB);
  });

  List<LatLng> hull = [pivot, sortedPoints.first];
  for (int i = 1; i < sortedPoints.length; i++) {
    LatLng top = hull.last;
    while (hull.length >= 2 &&
        cross(hull[hull.length - 2], top, sortedPoints[i]) <= 0) {
      hull.removeLast();
      if(hull.isNotEmpty)
        top = hull.last;
    }
    hull.add(sortedPoints[i]);
  }
  return hull;
}

// Fonction utilitaire pour calculer le produit vectoriel
double cross(LatLng o, LatLng a, LatLng b) {
  return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
      (a.latitude - o.latitude) * (b.longitude - o.longitude);
}

double calculatePolygonArea(List<LatLng> polygon) {
  double area = 0.0;
  if (polygon.length < 3) return area;
  for (int i = 0; i < polygon.length; i++) {
    LatLng p1 = polygon[i];
    LatLng p2 = polygon[(i + 1) % polygon.length];
    area += (p1.longitude * p2.latitude - p2.longitude * p1.latitude);
  }
  return (area / 2).abs() * 1e10;
}

List<LatLng> generateIntermediatePoints(LatLng start, LatLng end, int numSegments) {
  List<LatLng> intermediatePoints = [];
  for (int i = 1; i < numSegments; i++) {
    double fraction = i / numSegments;
    double lat = start.latitude + (end.latitude - start.latitude) * fraction;
    double lng = start.longitude + (end.longitude - start.longitude) * fraction;
    intermediatePoints.add(LatLng(lat, lng));
  }
  return intermediatePoints;
}
// Calcule la distance entre deux points (en degrés, ici)
double distanceBetween(LatLng a, LatLng b) {
  final double dx = a.latitude - b.latitude;
  final double dy = a.longitude - b.longitude;
  return sqrt(dx * dx + dy * dy);
}
double calculateDistance(LatLng point1, LatLng point2) {
  final double dx = point1.latitude - point2.latitude;
  final double dy = point1.longitude - point2.longitude;
  return sqrt(dx * dx + dy * dy);
}

double distanceToSegment(LatLng point, LatLng p1, LatLng p2) {
  final double x = point.latitude;
  final double y = point.longitude;
  final double x1 = p1.latitude;
  final double y1 = p1.longitude;
  final double x2 = p2.latitude;
  final double y2 = p2.longitude;

  final double A = x - x1;
  final double B = y - y1;
  final double C = x2 - x1;
  final double D = y2 - y1;

  final double dot = A * C + B * D;
  final double lenSq = C * C + D * D;
  double param = (lenSq != 0) ? dot / lenSq : -1;

  double xx, yy;

  if (param < 0) {
    xx = x1;
    yy = y1;
  } else if (param > 1) {
    xx = x2;
    yy = y2;
  } else {
    xx = x1 + param * C;
    yy = y1 + param * D;
  }

  final double dx = x - xx;
  final double dy = y - yy;
  return sqrt(dx * dx + dy * dy);
}

LatLng _projectPointOnSegment(LatLng point, LatLng p1, LatLng p2) {
  final double x = point.latitude;
  final double y = point.longitude;
  final double x1 = p1.latitude;
  final double y1 = p1.longitude;
  final double x2 = p2.latitude;
  final double y2 = p2.longitude;

  final double A = x - x1;
  final double B = y - y1;
  final double C = x2 - x1;
  final double D = y2 - y1;

  final double dot = A * C + B * D;
  final double lenSq = C * C + D * D;
  double param = (lenSq != 0) ? dot / lenSq : -1;

  if (param < 0) {
    return p1;
  } else if (param > 1) {
    return p2;
  } else {
    return LatLng(x1 + param * C, y1 + param * D);
  }
}
LatLng findNearestPointOnBoundary(LatLng tapPoint, List<List<LatLng>> fields) {
  LatLng nearestPoint = tapPoint;
  double minDistance = double.infinity;

  for (var field in fields) {
    for (int i = 0; i < field.length; i++) {
      LatLng p1 = field[i];
      LatLng p2 = field[(i + 1) % field.length];
      double distance = distanceToSegment(tapPoint, p1, p2);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = _projectPointOnSegment(tapPoint, p1, p2);
      }
    }
  }

  return nearestPoint;
}
List<LatLng> getFieldContour(List<LatLng> fieldPoints) {
  List<LatLng> contourPoints = [];
  for (int i = 0; i < fieldPoints.length; i++) {
    LatLng current = fieldPoints[i];
    LatLng next = fieldPoints[(i + 1) % fieldPoints.length];
    contourPoints.add(current);
    List<LatLng> intermediatePoints =
    generateIntermediatePoints(current, next, 10);
    contourPoints.addAll(intermediatePoints);
  }
  return contourPoints;
}
// Fonction qui retourne une liste de polylignes dashées à partir d'une polyligne (liste de points).
List<Polyline> createDashedPolylines({
  required List<LatLng> points,
  required double dashLength,
  required double gapLength,
  required Color color,
  required double strokeWidth,
}) {
  List<Polyline> dashedPolylines = [];

  // On parcourt chaque segment de la polyligne
  for (int i = 0; i < points.length - 1; i++) {
    LatLng start = points[i];
    LatLng end = points[i + 1];

    double segmentLength = distanceBetween(start, end);
    if (segmentLength == 0) continue;

    // Nombre de tirets pour ce segment
    int dashCount = (segmentLength / (dashLength + gapLength)).floor();
    // Différences pour passer d'un point à l'autre
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;

    for (int j = 0; j < dashCount; j++) {
      // Calcul des fractions pour le début et la fin du tiret
      double startFraction = (j * (dashLength + gapLength)) / segmentLength;
      double endFraction = ((j * (dashLength + gapLength)) + dashLength) / segmentLength;
      if (endFraction > 1.0) endFraction = 1.0;
      LatLng dashStart = LatLng(
        start.latitude + latDiff * startFraction,
        start.longitude + lngDiff * startFraction,
      );
      LatLng dashEnd = LatLng(
        start.latitude + latDiff * endFraction,
        start.longitude + lngDiff * endFraction,
      );

      dashedPolylines.add(
        Polyline(
          points: [dashStart, dashEnd],
          color: color,
          strokeWidth: strokeWidth,
        ),
      );
    }
  }

  return dashedPolylines;
}

// Vérifier si un point est dans un polygone
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  double minX = polygon[0].latitude;
  double maxX = polygon[0].latitude;
  double minY = polygon[0].longitude;
  double maxY = polygon[0].longitude;

  for (var p in polygon) {
    minX = min(minX, p.latitude);
    maxX = max(maxX, p.latitude);
    minY = min(minY, p.longitude);
    maxY = max(maxY, p.longitude);
  }

  if (point.latitude < minX ||
      point.latitude > maxX ||
      point.longitude < minY ||
      point.longitude > maxY) {
    return false;
  }

  bool inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    if ((polygon[i].longitude > point.longitude) !=
        (polygon[j].longitude > point.longitude) &&
        point.latitude <
            (polygon[j].latitude - polygon[i].latitude) *
                (point.longitude - polygon[i].longitude) /
                (polygon[j].longitude - polygon[i].longitude) +
                polygon[i].latitude) {
      inside = !inside;
    }
  }

  return inside;
}

bool SegmentsIntersect(LatLng p1, LatLng p2, LatLng q1, LatLng q2) {
  int orientation(LatLng a, LatLng b, LatLng c) {
    double val = (b.longitude - a.longitude) *
        (c.latitude - b.latitude) -
        (b.latitude - a.latitude) * (c.longitude - b.longitude);
    if (val == 0) return 0;
    return (val > 0) ? 1 : 2;
  }

  bool onSegment(LatLng p, LatLng q, LatLng r) {
    return q.latitude <= max(p.latitude, r.latitude) &&
        q.latitude >= min(p.latitude, r.latitude) &&
        q.longitude <= max(p.longitude, r.longitude) &&
        q.longitude >= min(p.longitude, r.longitude);
  }

  int o1 = orientation(p1, p2, q1);
  int o2 = orientation(p1, p2, q2);
  int o3 = orientation(q1, q2, p1);
  int o4 = orientation(q1, q2, p2);

  if (o1 != o2 && o3 != o4) return true;
  if (o1 == 0 && onSegment(p1, q1, p2)) return true;
  if (o2 == 0 && onSegment(p1, q2, p2)) return true;
  if (o3 == 0 && onSegment(q1, p1, q2)) return true;
  if (o4 == 0 && onSegment(q1, p2, q2)) return true;
  return false;
}
bool doesPolygonIntersect(List<LatLng> field1, List<LatLng> field2) {
  for (int i = 0; i < field1.length; i++) {
    LatLng p1 = field1[i];
    LatLng p2 = field1[(i + 1) % field1.length];
    for (int j = 0; j < field2.length; j++) {
      LatLng q1 = field2[j];
      LatLng q2 = field2[(j + 1) % field2.length];
      if (SegmentsIntersect(p1, p2, q1, q2)) {
        return true;
      }
    }
  }
  return false;
}