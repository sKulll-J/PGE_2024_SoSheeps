import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:universal_html/html.dart' as universal_html;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'geometry.dart';

void exportField(BuildContext context, List<LatLng> field, String fieldName, String fieldType) async {
  try {
    if (field.isEmpty) {
      throw Exception("Aucun champ à exporter.");
    }

    final fieldData = {
      'Nom': fieldName,
      'Type': fieldType,
      'Area': calculatePolygonArea(field),
      'polygon_coordinates': field
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(),
    };
    final jsonString = jsonEncode(fieldData);
    final fileName = "$fieldName.json";

    if (kIsWeb) {
      final blob = universal_html.Blob([jsonString], 'application/json');
      final url = universal_html.Url.createObjectUrlFromBlob(blob);
      final anchor = universal_html.document.createElement('a') as universal_html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;

      universal_html.document.body?.children.add(anchor);
      anchor.click();
      universal_html.document.body?.children.remove(anchor);
      universal_html.Url.revokeObjectUrl(url);
    } else {
      // Vérification des permissions
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        throw Exception("Permission de stockage refusée.");
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download'); // Vérifions si cela fonctionne
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception("Répertoire introuvable.");
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonString);

      print("✅ Fichier exporté à : ${file.path}"); // Affiche le chemin dans le debug console

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fichier enregistré : ${file.path}"),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print("❌ Erreur d'export : ${e.toString()}"); // Affiche l'erreur dans le debug console
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Erreur d'export : ${e.toString()}"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
