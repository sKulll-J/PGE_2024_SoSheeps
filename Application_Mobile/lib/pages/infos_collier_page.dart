import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InfosColliersPage extends StatefulWidget {
  const InfosColliersPage({super.key});

  @override
  _InfosColliersPageState createState() => _InfosColliersPageState();
}

class _InfosColliersPageState extends State<InfosColliersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _colliers = [];

  @override
  void initState() {
    super.initState();
    _fetchColliers();
  }

  /// 📡 Récupérer les colliers de l'utilisateur depuis Firebase
  void _fetchColliers() {
    String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Colliers')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _colliers = snapshot.docs.map((doc) {
          final data = doc.data();

          // ✅ Récupérer latitude et longitude depuis "geolocation"
          double latitude = 0.0;
          double longitude = 0.0;
          if (data.containsKey('geolocation') && data['geolocation'] is Map) {
            final geoData = data['geolocation'];
            latitude = (geoData['latitude'] ?? 0.0).toDouble();
            longitude = (geoData['longitude'] ?? 0.0).toDouble();
          }

          // ✅ Assurer que "battery_level" est bien un int (convertir si nécessaire)
          int batteryLevel = 0;
          if (data.containsKey("battery_level")) {
            batteryLevel = (data["battery_level"] is int)
                ? data["battery_level"]
                : (data["battery_level"] as num).toInt(); // Convertir double → int
          }

          print("📍 Collier ${doc.id} - Position : ($latitude, $longitude)");
          print("🔋 Batterie : $batteryLevel");

          return {
            "id": doc.id,
            "collar_id": data["collar_id"] ?? doc.id,
            "latitude": latitude,
            "longitude": longitude,
            "battery": batteryLevel, // ✅ Batterie toujours en int
            "lastUpdate": data["received_at"] ?? "Inconnu",
          };
        }).toList();
      });
    }, onError: (error) {
      print("❌ Erreur lors de la récupération des colliers: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de récupération des colliers.")),
      );
    });
  }

  ///  Déterminer la couleur de la batterie
  Color _getBatteryColor(int battery) {
    if (battery <= 20) return Colors.red;
    if (battery <= 50) return Colors.orange;
    return Colors.green;
  }

  ///  Formatter la date pour affichage
  String _formatDate(String date) {
    try {
      DateTime parsedDate = DateTime.parse(date).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } catch (e) {
      return "Inconnu";
    }
  }

  ///  Modifier le nom du collier (en renommant le document Firebase)
  void _editCollarName(String oldCollarId) async {
    TextEditingController nameController = TextEditingController(text: oldCollarId);
    String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Modifier le nom du collier"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Nouveau nom",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Annuler", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, nameController.text.trim());
              },
              child: const Text("Enregistrer", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != oldCollarId) {
      try {
        // Récupérer les données actuelles du collier
        DocumentSnapshot oldDoc = await _firestore
            .collection('Utilisateurs')
            .doc(userEmail)
            .collection('Colliers')
            .doc(oldCollarId)
            .get();

        if (oldDoc.exists) {
          Map<String, dynamic> collierData = oldDoc.data() as Map<String, dynamic>;

          // Supprimer l'ancien document
          await _firestore
              .collection('Utilisateurs')
              .doc(userEmail)
              .collection('Colliers')
              .doc(oldCollarId)
              .delete();

          // Créer un nouveau document avec le nouveau nom
          await _firestore
              .collection('Utilisateurs')
              .doc(userEmail)
              .collection('Colliers')
              .doc(newName)
              .set(collierData);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Collier renommé en : $newName"),
              behavior: SnackBarBehavior.fixed,),
          );
        }
      } catch (e) {
        print("Erreur lors du renommage du collier : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du changement de nom"),
            behavior: SnackBarBehavior.fixed,),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Infos des Colliers"),
        backgroundColor: Colors.green,
      ),
      body: _colliers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        shrinkWrap: true, // Garde cette ligne pour éviter l'overflow
        physics: const AlwaysScrollableScrollPhysics(), // Permet le scroll
        itemCount: _colliers.length,
        itemBuilder: (context, index) {
          final collier = _colliers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Icon(Icons.pets, color: Colors.green, size: 40),
                title: Text(
                  collier["id"],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  mainAxisSize: MainAxisSize.min, // Évite l'overflow
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Text("📌 Position: ${collier["latitude"]}, ${collier["longitude"]}"),
                    const SizedBox(height: 3),
                    Text(
                      "🆔 Collar ID: ${collier["collar_id"]}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "🕒 Dernière mise à jour: ${_formatDate(collier["lastUpdate"])}",
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("🔋 Batterie: "),
                        Flexible(
                          child: SizedBox(
                            width: 80,
                            height: 4, // Hauteur réduite pour éviter l’overflow
                            child: LinearProgressIndicator(
                              value: (collier["battery"] ?? 99) / 100, // Limite à 99% pour éviter l'overflow
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getBatteryColor(collier["battery"] ?? 0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text("${collier["battery"] ?? 0}%"),
                      ],
                    ),
                  ],
                ),
                trailing: Transform.translate(
                  offset: const Offset(-25, -70), // Ajuste la valeur pour monter l'icône
                  child: Icon(Icons.edit, color: Colors.grey),
                ),

                onTap: () => _editCollarName(collier["id"]),
              ),
            ),
          );
        },
      )


    );
  }
}
