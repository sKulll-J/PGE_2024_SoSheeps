import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AjouterCollierBackend {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ajoute un collier sous l'utilisateur connecté
  static Future<void> addCollar({
    required String collarName,
    required String collarId,
    required String animalType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté.");

    final userEmail = user.email!;
    final collarRef = _firestore
        .collection('Utilisateurs')
        .doc(userEmail)
        .collection('Colliers')
        .doc(collarName); // Nom du document = nom du collier

    await collarRef.set({
      'collar_id': collarId,
      'animal_type': animalType,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}
