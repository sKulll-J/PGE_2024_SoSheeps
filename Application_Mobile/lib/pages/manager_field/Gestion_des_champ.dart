// Importations des packages et bibliothèques nécessaires
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'my_location_button.dart';
import 'Controle_bouton.dart';
import 'geometry.dart';
import 'export.dart';
import 'snackbar.dart';
import 'Interface_modifier_champ.dart'; // pour accéder à MapType

// Déclaration de la page de la carte sous forme de StatefulWidget
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

// État de la MapPage avec SingleTickerProviderStateMixin pour l'animation
class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  // --- Variables générales ---
  double _userHeading = 0.0; // Angle d’orientation de l’utilisateur
  StreamSubscription<CompassEvent>? _compassSubscription;
  LatLng? userPosition; // Position actuelle de l'utilisateur
  StreamSubscription<Position>? positionStream;
  late AnimationController _blinkController; // Contrôleur pour l'animation de clignotement
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userEmail = FirebaseAuth.instance.currentUser!.email!;
  final MapController _mapController = MapController(); // Contrôleur de la carte
  final TextEditingController _searchController = TextEditingController();
  MapType _currentMapType = MapType.normal; // Type de carte actuel

  // --- Variables liées aux champs ---
  List<List<LatLng>> fields = []; // Liste des champs (polygones)
  List<Color> fieldColors = []; // Couleurs d'affichage des champs
  List<Color> borderColors = []; // Couleurs des bordures des champs
  List<String> fieldNames = []; // Noms des champs
  List<String> fieldIds = []; // Identifiants des champs (IDs)
  List<String> fieldTypes = []; // Types de champs (ex. Active, Inactive, Interdit)
  List<LatLng> currentField = []; // Points du champ en cours de dessin
  List<LatLng> domain = []; // Domaine total en enveloppe convexe
  bool isDrawing = false; // Indique si l'utilisateur est en mode dessin
  bool domainDefined = false;
  final double snappingThreshold = 0.00045; // Seuil pour l'alignement (snap) des points
  List<LatLng> temporaryPoints = []; // Points temporaires pour l'affichage lors du dessin

  // --- Variables liées aux animaux ---
  Map<String, LatLng> _animalPositions = {}; // Positions des animaux (par collier)
  Map<String, int> _batteryLevels = {}; // Niveaux de batterie des colliers
  Map<String, String> _collarIDs = {}; // IDs des colliers
  Map<String, String> _lastUpdateTimes = {}; // Dernière mise à jour pour chaque collier
  Map<String, String> _animalTypes = {}; // Types d'animaux (ex. mouton, chien, etc.)

  bool isDrawingDomain = false;
  final double onBoundaryTolerance = 0.1;
  Future<void>? _futureRequest;
  bool isDialogOpen = false;

  // INITIALISATION DE L'ÉTAT
  @override
  void initState() {
    super.initState();
    // Récupération des champs depuis Firebase
    fetchFields();
    // Déplacement initial vers la localisation de l'utilisateur après le chargement du widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveToUserLocation();
    });

    // Lancement de l'écoute des mises à jour de la localisation
    _listenToPositionUpdates();

    // Écoute de l'orientation via la boussole
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        if (!mounted) return; // Vérifie que le widget est toujours actif
        setState(() {
          _userHeading = event.heading!; // Mise à jour de l'angle en degrés
        });
      }
    });

    // Initialisation du contrôleur d'animation pour le clignotement
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      lowerBound: 0.3,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  // Nettoyage des ressources lors de la suppression du widget
  @override
  void dispose() {
    _blinkController.dispose();
    positionStream?.cancel(); // Annulation du flux de localisation
    _searchController.dispose();
    _compassSubscription?.cancel(); // Arrêt de l'écoute de la boussole
    _futureRequest = null; // Annulation du Future si nécessaire
    super.dispose();
  }

  // --- Gestion de la localisation utilisateur ---

  // Déplacement de la carte vers la localisation de l'utilisateur
  Future<void> _moveToUserLocation() async {
    bool hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Permission de localisation refusée.")),
      );
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Activez le service de localisation.")),
      );
      return;
    }

    try {
      positionStream?.cancel(); // Annuler l'ancien stream si existant

      // ✅ Vérifier d'abord la dernière position connue
      Position? position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        print("⚠️ Aucune position connue, récupération en cours...");
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
      } else {
        print("📍 Dernière position connue récupérée !");
      }

      // ✅ Vérifier si la position a été obtenue
      if (position != null) {
        if (!mounted) return;
        setState(() => userPosition = position != null
            ? LatLng(position!.latitude, position!.longitude)
            : LatLng(0.0, 0.0)); // Default location if position is null


        // ✅ Forcer le rafraîchissement après une petite pause
        await Future.delayed(Duration(milliseconds: 200));

        _mapController.move(userPosition!, 18.0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de récupérer la localisation.")),
        );
      }

    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Localisation trop longue - vérifiez votre GPS"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("❌ Erreur localisation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la récupération de la localisation.")),
      );
    }
  }




  // Vérification et demande de permission de localisation
  Future<bool> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    print("🛑 Permission actuelle : $permission");

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  // --- Gestion des champs ---

  // Récupération des champs stockés dans Firebase pour l'utilisateur
  void fetchFields() async {
    final querySnapshot = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .get();

    // Filtrer le document "Domaine" s'il existe
    final filteredDocs = querySnapshot.docs.where((doc) => doc.id != 'Domaine').toList();
    if (!mounted) return; // Vérifie que le widget est toujours actif
    setState(() {
      fields = filteredDocs
          .map((doc) => (doc['polygon_coordinates'] as List)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList())
          .toList();

      fieldNames = filteredDocs.map((doc) => doc['Nom'] as String).toList();
      fieldIds = filteredDocs.map((doc) => doc.id).toList();
      fieldTypes = filteredDocs
          .map((doc) => doc['Type'] as String? ?? 'Active')
          .toList();

      // Définition des couleurs de remplissage en fonction du type de champ
      fieldColors = fieldTypes.map((type) {
        switch (type) {
          case 'Active':
            return Colors.green.withOpacity(0.4);
          case 'Inactive':
            return Color(0xFFF0F4C3).withOpacity(0.4);
          case 'Interdit':
            return Colors.red.withOpacity(0.4);
          default:
            return Colors.green.withOpacity(0.4);
        }
      }).toList();

      // Définition des couleurs de bordure en fonction du type de champ
      borderColors = fieldTypes.map((type) {
        switch (type) {
          case 'Active':
            return Colors.green;
          case 'Inactive':
            return Color(0xFFF0F4C3);
          case 'Interdit':
            return Colors.red;
          default:
            return Colors.green;
        }
      }).toList();
    });
    // Mise à jour du domaine total
    updateTotalDomain();
  }

  // Calcul et mise à jour de l'enveloppe convexe (domaine total)
  Future<void> updateTotalDomain() async {
    List<LatLng> allPoints = [];
    for (var field in fields) {
      allPoints.addAll(field);
    }
    if (allPoints.isNotEmpty) {
      List<LatLng> hull = computeConvexHull(allPoints);
      if (!mounted) return; // Vérifie que le widget est toujours actif
      setState(() {
        domain = hull;
      });
      // Enregistrement dans Firebase dans la sous-collection "DomaineTotal"
      await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .doc('Domaine')
          .set({
        'polygon_coordinates': hull
            .map((p) => GeoPoint(p.latitude, p.longitude))
            .toList(),
        'Time': FieldValue.serverTimestamp(),
      });
    } else {
      if (!mounted) return; // Vérifie que le widget est toujours actif
      setState(() {
        domain = [];
      });
      // Suppression du document si aucun champ n'existe
      await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .doc('Domaine')
          .delete();
    }
  }

  // Écoute des mises à jour de position des colliers (animaux) dans Firebase
  void _listenToPositionUpdates() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userEmail = user.email ?? '';

      _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Colliers')
          .snapshots()
          .listen((collarCollection) {
        if (collarCollection.docs.isNotEmpty) {
          collarCollection.docs.forEach((collarDoc) {
            String collarName = collarDoc.id;
            print("📡 Vérification du collier : $collarName");

            // Récupération des informations du collier
            final data = collarDoc.data();

            // ✅ Vérification et récupération de la position sous "geolocation"
            double latitude = 0.0;
            double longitude = 0.0;
            if (data.containsKey('geolocation') && data['geolocation'] is Map) {
              final geoData = data['geolocation'];
              latitude = (geoData['latitude'] ?? 0.0).toDouble();
              longitude = (geoData['longitude'] ?? 0.0).toDouble();
            }

            // ✅ Récupération des autres données du collier
            String collarID = data["collar_id"] ?? "Unknown";
            int batteryLevel = (data["battery_level"] ?? 0).toInt();
            String lastUpdate = data["received_at"] ?? "Inconnu";
            String animalType = data["animal_type"] ?? "mouton"; // Par défaut un mouton

            if (!mounted) return;
            setState(() {
              _animalPositions[collarName] = LatLng(latitude, longitude);
              _collarIDs[collarName] = collarID;
              _batteryLevels[collarName] = batteryLevel;
              _lastUpdateTimes[collarName] = lastUpdate;
              _animalTypes[collarName] = animalType;
            });

            print("📍 Position mise à jour pour $collarName : ($latitude, $longitude)");
            print("🔋 Batterie : $batteryLevel% | 🆔 ID : $collarID | 🕒 MAJ : $lastUpdate");
          });
        } else {
          print("⚠️ Aucun collier trouvé pour l'utilisateur : $userEmail");
        }
      }, onError: (e) => print("❌ Erreur lors de la récupération des colliers : $e"));
    }
  }


  // Fonction de recherche de localisation via l'API Nominatim
  Future<void> _searchLocation(String query) async {
    final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'flutter_map_app'
      });
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);
          LatLng searchedPosition = LatLng(lat, lon);
          // Déplacement de la carte vers la position recherchée
          _mapController.move(searchedPosition, 18.0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun résultat trouvé pour cette recherche.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la recherche de la localisation.")),
        );
      }
    } catch (e) {
      print("Erreur lors de la recherche: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la recherche de la localisation.")),
      );
    }
  }

  // --- Fonctions pour la gestion du dessin d'un champ ---

  // Active le mode dessin pour ajouter un nouveau champ
  void addMainField() {
    if (!mounted) return; // Vérifie que le widget est toujours actif
    setState(() {
      isDrawing = true;
      currentField.clear();
      temporaryPoints.clear();
    });
    showStylishSnackBar(
      "Mode dessin activé !\nPlacez des points sur la carte pour définir le champ.\nPour fermer le champ, touchez le premier point.",
      backgroundColor: Colors.blue,
    );
  }

  // Demande à l'utilisateur le nom du champ et affiche l'aire calculée
  Future<String?> askForFieldName(double area) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        String name = '';
        return AlertDialog(
          title: const Text('Nom du champ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Entrez le nom du champ'),
                onChanged: (value) {
                  name = value;
                },
              ),
              const SizedBox(height: 10),
              Text("Aire du champ: ${area.toStringAsFixed(2)} m²"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, name);
              },
              child:
              const Text('Valider', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Extraction des points de contour pour chaque champ
  Map<String, List<LatLng>> extractFieldBoundaries( List<List<LatLng>> fields, List<String> fieldNames ) {
    Map<String, List<LatLng>> fieldBoundaries = {};
    for (int i = 0; i < fields.length; i++) {
      List<LatLng> contourPoints = getFieldContour(fields[i]);
      fieldBoundaries[fieldNames[i]] = contourPoints;
    }
    return fieldBoundaries;
  }

  // Fonction de test et d'affichage du contour des champs (pour debug)
  void fetchFields_Distance() async {
    final querySnapshot = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .get();

    List<List<LatLng>> fetchedFields = querySnapshot.docs.map((doc) {
      return (doc['polygon_coordinates'] as List)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }).toList();

    List<String> fetchedFieldNames =
    querySnapshot.docs.map((doc) => doc['Nom'] as String).toList();

    Map<String, List<LatLng>> fieldContours =
    extractFieldBoundaries(fetchedFields, fetchedFieldNames);

    fieldContours.forEach((fieldName, points) {
      print("Contour du champ $fieldName : ${points.length} points.");
    });
  }

  // --- Fonctions de géométrie et de "snap" des points ---

  // Projection d'un point sur un segment défini par p1 et p2
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

  // Ajuste (snap) le point sur la limite d'un champ si proche d'une bordure
  LatLng snapToNearestFieldBoundary(LatLng point, double threshold) {
    double minDistance = double.infinity;
    LatLng snappedPoint = point;
    for (var field in fields) {
      for (int i = 0; i < field.length; i++) {
        LatLng p1 = field[i];
        LatLng p2 = field[(i + 1) % field.length];
        double d = distanceToSegment(point, p1, p2);
        if (d < minDistance) {
          minDistance = d;
          snappedPoint = _projectPointOnSegment(point, p1, p2);
        }
      }
    }
    if (minDistance < threshold) {
      return snappedPoint;
    } else {
      return point;
    }
  }

  // --- Fonctions de suppression et de modification de champs ---

  // Suppression d'un champ identifié par son ID dans Firebase
  void deleteField(String fieldId) async {
    await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(fieldId)
        .delete();
    fetchFields();
    // Mise à jour du domaine total après suppression
    updateTotalDomain();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Le champ a été supprimé avec succès !"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Affichage d'une boîte de dialogue pour sélectionner et supprimer un champ
  void showDeleteFieldDialog() async {
    final querySnapshot = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .get();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer un champ'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: querySnapshot.docs.length,
              itemBuilder: (context, index) {
                final doc = querySnapshot.docs[index];

                // Vérifier si le champ "Nom" existe avant d'afficher
                if (!doc.data().containsKey("Nom")) {
                  return const SizedBox(); // Ignore ce document
                }

                return ListTile(
                  title: Text(doc['Nom']),
                  onTap: () {
                    Navigator.pop(context);
                    deleteField(doc.id);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Renommage d'un champ existant en modifiant également l'ID du document dans Firebase
  void renameField(String fieldId, String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le nom du champ ne peut pas être vide."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier si un document avec le nouveau nom existe déjà
    final existingSnapshot = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(newName)
        .get();
    if (existingSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ce nom de champ existe déjà. Veuillez en choisir un autre."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Récupérer les données de l'ancien document
    final DocumentSnapshot oldDoc = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(fieldId)
        .get();

    if (!oldDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le champ à renommer est introuvable."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<String, dynamic> data = oldDoc.data() as Map<String, dynamic>;
    // Mise à jour du champ "Nom" dans les données
    data['Nom'] = newName;

    // Création d'un nouveau document avec le nouvel ID et copie des données
    await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(newName)
        .set(data);

    // Suppression de l'ancien document
    await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(fieldId)
        .delete();

    // Mise à jour de l'affichage
    fetchFields();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Le champ a été renommé avec succès !"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Boîte de dialogue pour renommer un champ
  void showRenameFieldDialog(String fieldId, String currentName) {
    TextEditingController renameController =
    TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renommer le champ'),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(
                hintText: 'Entrez le nouveau nom du champ'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                String newName = renameController.text.trim();
                if (newName.isNotEmpty) {
                  renameField(fieldId, newName);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Le nom du champ ne peut pas être vide."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Valider', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Boîte de dialogue pour sélectionner un champ à renommer
  void showSelectFieldToRenameDialog() async {
    final querySnapshot = await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .get();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sélectionner un champ à renommer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: querySnapshot.docs.length,
              itemBuilder: (context, index) {
                final doc = querySnapshot.docs[index];

                // Vérification de l'existence du champ "Nom"
                if (!doc.data().containsKey("Nom")) {
                  return const SizedBox(); // Ignore ce document
                }

                return ListTile(
                  title: Text(doc['Nom']),
                  onTap: () {
                    Navigator.pop(context);
                    showRenameFieldDialog(doc.id, doc['Nom']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Changement du type d'un champ dans Firebase
  void changeTypeChamp(String fieldId, String newType) async {
    await _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .doc(fieldId)
        .update({
      'Type': newType,
    });
    fetchFields();
  }

  // Boîte de dialogue pour choisir le type d'un champ
  void showChangeTypeDialog(BuildContext context, String fieldId, String currentType, Function(String, String) changeTypeCallback) {
    String selectedType = currentType;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Choisir le type de champ'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: const Text('Active', style: TextStyle(color: Colors.green)),
                      value: 'Active',
                      groupValue: selectedType,
                      onChanged: (value) => setState(() => selectedType = value!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Inactive', style: TextStyle(color: Colors.blueGrey)),
                      value: 'Inactive',
                      groupValue: selectedType,
                      onChanged: (value) => setState(() => selectedType = value!),
                      tileColor: Color(0xFFF0F4C3).withOpacity(0.8),
                    ),
                    RadioListTile<String>(
                      title: const Text('Interdit', style: TextStyle(color: Colors.red)),
                      value: 'Interdit',
                      groupValue: selectedType,
                      onChanged: (value) => setState(() => selectedType = value!),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () {
                      changeTypeCallback(fieldId, selectedType);
                      Navigator.pop(context);
                    },
                    child: const Text('Valider', style: TextStyle(color: Colors.teal)),
                  ),
                ],
              );
            });
      },
    );
  }

  // Boîte de dialogue pour sélectionner un champ et changer son type
  void showSelectFieldToChangeTypeDialog(BuildContext context, FirebaseFirestore firestore, String userEmail) async {
    final querySnapshot = await firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Champ')
        .get();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sélectionner un champ'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: querySnapshot.docs.length,
              itemBuilder: (context, index) {
                final doc = querySnapshot.docs[index];

                // Vérification des clés "Nom" et "Type"
                if (!doc.data().containsKey("Nom") || !doc.data().containsKey("Type")) {
                  return const SizedBox(); // Ignore ce document
                }

                return ListTile(
                  title: Text(doc['Nom']),
                  onTap: () {
                    Navigator.pop(context);
                    showChangeTypeDialog(context, doc.id, doc['Type'], changeTypeChamp);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Suppression de tous les champs après confirmation de l'utilisateur
  void deleteAllFields(BuildContext context, FirebaseFirestore firestore, String userEmail) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer tous les champs'),
          content: const Text(
              'Êtes-vous sûr de vouloir supprimer tous les champs ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      final querySnapshot = await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      // Mise à jour de l'affichage après suppression
      fetchFields();
      setState(() {
        fields.clear();
        fieldColors.clear();
        borderColors.clear();
        fieldNames.clear();
        fieldIds.clear();
      });
      // Mise à jour du domaine total
      updateTotalDomain();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tous les champs ont été supprimés avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Si annulation, rafraîchir l'affichage
      fetchFields();
    }
  }

  // Boîte de dialogue pour sélectionner un champ à exporter
  void showExportFieldDialog(BuildContext context, List<List<LatLng>> fields, List<String> fieldNames, List<String> fieldTypes, Function exportField) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sélectionner un champ à exporter'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fields.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(fieldNames[index]),
                  onTap: () {
                    Navigator.pop(context);
                    exportField(context, fields[index], fieldNames[index], fieldTypes[index]);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  // Demande à l'utilisateur le nom de fichier pour l'exportation
  Future<String?> askFileName(BuildContext context) async {
    TextEditingController fileNameController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Nom du fichier"),
          content: TextField(
            controller: fileNameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nom du fichier",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, fileNameController.text.trim());
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Importation d'un champ à partir d'un fichier JSON
  void importFields(BuildContext context, FirebaseFirestore firestore, String userEmail, List fields, bool Function(List<LatLng>, List<LatLng>) doesPolygonIntersect) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Importation annulée."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = result.files.single;
    if (!file.name.endsWith('.json')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un fichier JSON valide."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String jsonString;

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception("Impossible de lire le fichier.");
        jsonString = utf8.decode(bytes);
      } else {
        if (file.bytes != null) {
          jsonString = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          final File localFile = File(file.path!);
          jsonString = await localFile.readAsString();
        } else {
          throw Exception("Fichier non valide.");
        }
      }

      final Map<String, dynamic> fieldData = jsonDecode(jsonString);

      final String importedName = fieldData['Nom'] ?? 'Champ sans nom';
      final String importedType = fieldData['Type'] ?? 'Active';
      final List<dynamic> pointsData = fieldData['polygon_coordinates'] ?? [];

      final List<LatLng> importedField = pointsData
          .map((point) => LatLng(point['latitude'], point['longitude']))
          .toList();

      final List<GeoPoint> geoPoints = importedField
          .map((point) => GeoPoint(point.latitude, point.longitude))
          .toList();

      final existingFields = await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .where('Nom', isEqualTo: importedName)
          .get();

      if (existingFields.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Le champ '$importedName' existe déjà."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      bool hasIntersection = fields.any((existingField) {
        return doesPolygonIntersect(existingField, importedField);
      });

      if (hasIntersection) {
        bool? userDecision = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("⚠️ Attention : Intersection détectée"),
              content: Text(
                  "Le champ '$importedName' intersecte un champ existant. Voulez-vous continuer l'importation ?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Annuler", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Continuer", style: TextStyle(color: Colors.teal)),
                ),
              ],
            );
          },
        );

        if (userDecision == false) {
          return;
        }
      }

      // Enregistrement du champ importé dans Firebase
      await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .doc(importedName)
          .set({
        'Nom': importedName,
        'Type': importedType,
        'Area': calculatePolygonArea(importedField),
        'polygon_coordinates': geoPoints,
        'Time': FieldValue.serverTimestamp(),
      });

      fetchFields();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le champ a été importé avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'importation : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Construction du menu de l'AppBar ---

  // Menu contextuel présent dans l'AppBar pour gérer les champs
  Widget _buildAppBarMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.black),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add',
          child: ListTile(
            leading: Icon(Icons.add_location, color: Colors.teal),
            title: Text('Nouveau champ'),
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit, color: Colors.teal),
            title: Text('Renommer un champ'),
          ),
        ),
        const PopupMenuItem(
          value: 'type',
          child: ListTile(
            leading: Icon(Icons.layers, color: Colors.teal),
            title: Text('Type de champ'),
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.upload, color: Colors.teal),
            title: Text('Exporter'),
          ),
        ),
        const PopupMenuItem(
          value: 'import',
          child: ListTile(
            leading: Icon(Icons.download, color: Colors.teal),
            title: Text('Importer'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Supprimer un champ', style: TextStyle(color: Colors.red)),
          ),
        ),
        PopupMenuItem(
          value: 'delete_all',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Supprimer tout les champs', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'add':
            addMainField();
            break;
          case 'rename':
            showSelectFieldToRenameDialog();
            break;
          case 'type':
            showSelectFieldToChangeTypeDialog(context, _firestore, userEmail);
            break;
          case 'export':
            showExportFieldDialog(context, fields, fieldNames, fieldTypes, exportField);
            break;
          case 'import':
            importFields(context, _firestore, userEmail, fields, doesPolygonIntersect);
            break;
          case 'delete':
            showDeleteFieldDialog();
            break;
          case 'delete_all':
            deleteAllFields(context, _firestore, userEmail);
            break;
        }
      },
    );
  }

  // --- Fonctions pour le dessin du champ ---

  // Annule le dernier point ajouté lors du dessin
  void _undoLastPoint() {
    if (!mounted) return; // Vérifie que le widget est toujours actif
    setState(() {
      if (currentField.isNotEmpty) currentField.removeLast();
      if (temporaryPoints.isNotEmpty) temporaryPoints.removeLast();
    });
  }

  // Efface l'ensemble du dessin en cours
  void _clearDrawing() {
    if (!mounted) return; // Vérifie que le widget est toujours actif
    setState(() {
      currentField.clear();
      temporaryPoints.clear();
      isDrawing = false;
    });
  }

  // Construction des contrôles d'édition lors du dessin (Annuler, Effacer, Valider)
  Widget _buildDrawingControls() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ControlButton(
            icon: Icons.undo,
            label: 'Annuler',
            onPressed: _undoLastPoint,
            color: Colors.orange,
          ),
          ControlButton(
            icon: Icons.delete,
            label: 'Effacer',
            onPressed: _clearDrawing,
            color: Colors.red,
          ),
          ControlButton(
            icon: Icons.check_circle,
            label: 'Valider',
            onPressed: validateField,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  // Validation du champ dessiné, calcul de l'aire et enregistrement dans Firebase
  void validateField() async {
    if (currentField.length > 2) {
      // Fermeture du polygone si nécessaire
      if (currentField.first != currentField.last) {
        currentField.add(currentField.first);
      }
      double area = calculatePolygonArea(currentField);

      String? fieldName;
      bool isNameValid = false;
      // Boucle pour s'assurer d'un nom valide et unique
      while (!isNameValid) {
        fieldName = await askForFieldName(area);
        if (fieldName == null || fieldName.isEmpty) {
          showStylishSnackBar("Veuillez saisir un nom pour le champ.", backgroundColor: Colors.red);
          continue;
        }
        final querySnapshot = await _firestore
            .collection('Utilisateurs')
            .doc(userEmail)
            .collection('Champ')
            .where('Nom', isEqualTo: fieldName)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          showStylishSnackBar("Ce nom existe déjà. Choisissez un autre.", backgroundColor: Colors.red);
        } else {
          isNameValid = true;
        }
      }

      // Conversion des points en GeoPoints pour Firebase
      List<GeoPoint> geoPoints = currentField
          .map((point) => GeoPoint(point.latitude, point.longitude))
          .toList();

      // Enregistrement du nouveau champ dans Firebase
      await _firestore
          .collection('Utilisateurs')
          .doc(userEmail)
          .collection('Champ')
          .doc(fieldName)
          .set({
        'Nom': fieldName,
        'polygon_coordinates': geoPoints,
        'Time': FieldValue.serverTimestamp(),
        'Type': 'Inactive',
        'Area': area,
      });
      if (!mounted) return; // Vérifie que le widget est toujours actif
      setState(() {
        fields.add(List.from(currentField));
        fieldNames.add(fieldName!);
        fieldTypes.add('Inactive');
        fieldColors.add(Colors.green.withOpacity(0.4));
        borderColors.add(Colors.green);
        isDrawing = false;
        currentField.clear();
        temporaryPoints.clear();
      });
      fetchFields();
      // Mise à jour du domaine total après ajout du champ
      updateTotalDomain();
      showStylishSnackBar("Champ '$fieldName' validé et enregistré !", backgroundColor: Colors.green);
    } else {
      showStylishSnackBar("Le champ doit comporter au moins 3 points.", backgroundColor: Colors.red);
    }
  }

  // --- Construction de l'interface principale ---

  @override
  Widget build(BuildContext context) {
    // Calcul des polylignes dashées pour représenter le domaine total
    List<Polyline> dashedDomainPolylines = [];
    if (domain.isNotEmpty) {
      // Fermeture du polygone en ajoutant le premier point à la fin
      List<LatLng> domainClosed = List.from(domain)..add(domain.first);
      dashedDomainPolylines = createDashedPolylines(
        points: domainClosed,
        dashLength: 0.00005,
        gapLength: 0.00009,
        color: Colors.blue,
        strokeWidth: 2,
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          // Carte interactive FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              //center: LatLng(43.5599, 1.4694734),
              initialZoom: 18.0,
              minZoom: 5.0,
              maxZoom: 18,
              //interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              onTap: (tapPosition, point) {
                // Traitement du tap lors du mode dessin
                if (!isDrawing) return;
                // Calcul du point ajusté (snap)
                LatLng snappedPoint = snapToNearestFieldBoundary(point, snappingThreshold);
                if (!mounted) return;
                setState(() {
                  currentField.add(snappedPoint);
                  temporaryPoints.add(snappedPoint);
                });
                // Si le dessin est presque fermé, valider automatiquement
                if (currentField.length > 2) {
                  final distance = calculateDistance(currentField.first, currentField.last);
                  if (distance < 0.0001) {
                    if (!mounted) return;
                    setState(() {
                      currentField.add(currentField.first);
                      isDrawing = false;
                    });
                    validateField();
                    return;
                  }
                }
              },
            ),
            children: [
              // Couche de tuiles pour l'affichage de la carte
              TileLayer(
                urlTemplate: _getMapUrl(_currentMapType),
                subdomains: const ['a', 'b', 'c'],
              ),
              // Couche des polygones pour les champs
              PolygonLayer(
                polygons: fields.asMap().entries.map((entry) {
                  return Polygon(
                    points: entry.value,
                    color: fieldColors[entry.key].withOpacity(0.4),
                    borderColor: borderColors[entry.key],
                    borderStrokeWidth: 2,
                    //isFilled: true,
                  );
                }).toList(),
              ),
              // Couche des polylignes dashées pour le domaine total
              if (dashedDomainPolylines.isNotEmpty)
                PolylineLayer(
                  polylines: dashedDomainPolylines,
                ),
              // Couche d'aperçu du dessin en cours
              if (currentField.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: currentField,
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  ],
                ),
              // Couche des marqueurs pour les champs et la position de l'utilisateur
              MarkerLayer(
                markers: [
                  ...fields.asMap().entries.map((entry) {
                    if (entry.value.isNotEmpty) {
                      // Calcul du centre du champ pour positionner le marqueur
                      final centerLat = entry.value.map((p) => p.latitude).reduce((a, b) => a + b) / entry.value.length;
                      final centerLng = entry.value.map((p) => p.longitude).reduce((a, b) => a + b) / entry.value.length;
                      return Marker(
                        point: LatLng(centerLat, centerLng),
                        width: 40,   // obligatoire
                        height: 40,  // obligatoire
                        child: GestureDetector(
                          onTap: () {
                            showChangeTypeDialog(
                              context,
                              fieldIds[entry.key],
                              fieldTypes[entry.key],
                              changeTypeChamp,
                            );
                          },
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 35,
                          ),
                        ),
                      );
                    } else {
                      return Marker(
                        point: LatLng(0, 0),
                        child:  SizedBox(),
                      );
                    }
                  }),
                  // Marqueur pour la position de l'utilisateur
                  if (userPosition != null)
                    Marker(
                      point: userPosition!,
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: _userHeading * (pi / 180), // Conversion degrés → radians
                        child: const Icon(
                          Icons.navigation, // Flèche directionnelle
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ),

                  // Marqueurs pour les points temporaires du dessin
                  ...temporaryPoints.map((point) => Marker(
                    point: point,
                    width: 30,   // tu peux ajuster selon la taille
                    height: 30,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 24,
                    ),
                  )),

                ],
              ),
              // Couche des marqueurs pour les animaux (colliers)
              if (_animalPositions.isNotEmpty)
                MarkerLayer(
                  markers: _animalPositions.entries.map((entry) {
                    String collarName = entry.key;
                    LatLng position = entry.value;
                    int batteryLevel = _batteryLevels[collarName] ?? 0;
                    String collarID = _collarIDs[collarName] ?? "Unknown";
                    String receivedAt = _lastUpdateTimes[collarName] ?? "Unknown";
                    String animalType = _animalTypes[collarName] ?? "mouton";

                    // Choix de l'icône en fonction de l'animal
                    String iconPath = (animalType == "Chien") ? 'assets/icon/dog.png' : 'assets/icon/icon1.png';
                    // Détermination de la couleur de la batterie
                    Color batteryColor;
                    if (batteryLevel <= 20) {
                      batteryColor = Colors.red;
                    } else if (batteryLevel <= 49) {
                      batteryColor = Colors.yellow;
                    } else if (batteryLevel <= 69) {
                      batteryColor = Colors.orange;
                    } else {
                      batteryColor = Colors.green;
                    }

                    return Marker(
                      point: position,
                      width: 40.0,
                      height: 40.0,
                      child: GestureDetector(
                        onTap: () {
                          print("📌 Collier cliqué: $collarName");
                          _showSheepDetails(context, collarName, collarID, batteryLevel, receivedAt);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _blinkController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _blinkController.value,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_currentMapType == MapType.satellite) ? Colors.white : Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: ClipOval(
                                      child: Image.asset(
                                        iconPath, // Image dynamique selon l'animal
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: CircularProgressIndicator(
                                value: batteryLevel / 100,
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          // Bouton flottant pour afficher le menu de gestion des champs (en bas à droite)
          Positioned(
            bottom: 163,
            right: 18,
            child: FloatingActionButton(
              tooltip: 'Gérer les champs',
              onPressed: () {},
              backgroundColor: Colors.teal,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.edit, color: Colors.white),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.add_location, color: Colors.teal),
                      title: Text('Nouveau champ'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.teal),
                      title: Text('Renommer un champ'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'type',
                    child: ListTile(
                      leading: Icon(Icons.layers, color: Colors.teal),
                      title: Text('Type de champ'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.upload, color: Colors.teal),
                      title: Text('Exporter'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.download, color: Colors.teal),
                      title: Text('Importer'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Supprimer un champ', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Supprimer tout les champs', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      addMainField();
                      break;
                    case 'rename':
                      showSelectFieldToRenameDialog();
                      break;
                    case 'type':
                      showSelectFieldToChangeTypeDialog(context, _firestore, userEmail);
                      break;
                    case 'export':
                      showExportFieldDialog(context, fields, fieldNames, fieldTypes, exportField);
                      break;
                    case 'import':
                      importFields(context, _firestore, userEmail, fields, doesPolygonIntersect);
                      break;
                    case 'delete':
                      showDeleteFieldDialog();
                      break;
                    case 'delete_all':
                      deleteAllFields(context, _firestore, userEmail);
                      break;
                  }
                },
              ),
            ),
          ),
          // Barre de recherche pour trouver une adresse
          Builder(
              builder: (context) {
                return Positioned(
                  top: 50,
                  left: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: "Rechercher une adresse...",
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            final query = _searchController.text;
                            if (query.isNotEmpty) {
                              _searchLocation(query);
                            }
                          },
                        ),
                      ),
                      onSubmitted: (query) {
                        if (query.isNotEmpty) {
                          _searchLocation(query);
                        }
                      },
                    ),
                  ),
                );
              }
          ),
        ],
      ),
      // Affichage des contrôles de dessin en bas si l'utilisateur est en mode dessin
      bottomNavigationBar: isDrawing ? _buildDrawingControls() : null,
      // Boutons flottants pour changer le type de carte et recentrer sur la position de l'utilisateur
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btnMapType",
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _currentMapType = MapType.values[(_currentMapType.index + 1) % MapType.values.length];
              });
            },
            child: const Icon(Icons.map),
            tooltip: 'Changer le type de carte',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () async {
              await _moveToUserLocation();
            },
            child: const Icon(Icons.my_location),
            tooltip: 'Afficher ma position',
          ),


        ],
      ),
    );
  }

  // --- Fonction utilitaire pour récupérer l'URL des tuiles en fonction du type de carte ---
  String _getMapUrl(MapType mapType) {
    switch (mapType) {
      case MapType.satellite:
        return "https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}";
      case MapType.terrain:
        return "https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png";
      case MapType.normal:
      default:
        return "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
    }
  }
}

// --- Fonction hors de la classe pour afficher les détails de l'animal dans une BottomSheet ---

void _showSheepDetails(BuildContext context, String name, String id, int batteryLevel, String receivedAt) {
  // Conversion de la date reçue en un format lisible
  String formattedDateTime = "Inconnu";
  try {
    DateTime parsedDateTime = DateTime.parse(receivedAt).toLocal();

    formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(parsedDateTime);
  } catch (e) {
    print("Erreur de parsing de la date: $e");
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets, // Ajustement pour le clavier
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre et icône
              Row(
                children: [
                  Icon(Icons.pets, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    "Informations sur l'animal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Détails de l'animal
              _buildDetailTile(Icons.label, "Nom", name),
              _buildDetailTile(Icons.tag, "ID", id),
              _buildDetailTile(Icons.battery_charging_full, "Niveau de Batterie", "$batteryLevel%"),
              _buildDetailTile(Icons.access_time, "Dernière MAJ", formattedDateTime),
              SizedBox(height: 12),
              // Bouton pour fermer
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: Text(
                    'Fermer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Fonction d'aide pour créer une ligne de détail stylisée
Widget _buildDetailTile(IconData icon, String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        SizedBox(width: 8),
        Text(
          "$title: $value",
          style: TextStyle(fontSize: 16),
        ),
      ],
    ),
  );
}
