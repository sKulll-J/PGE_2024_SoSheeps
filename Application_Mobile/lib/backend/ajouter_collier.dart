import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AjouterCollierBackend {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ajoute un collier sous l'utilisateur connecté
  /// Vérifie que le collarId n'existe pas déjà dans "EndNode_user"
  static Future<void> addCollar({
    required String collarName,
    required String collarId,
    required String animalType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté.");

    final userEmail = user.email!;

    // 1️⃣ Vérification si le collier existe déjà
    final collarDoc = await _firestore.collection('EndNode_user').doc(collarId).get();

    if (collarDoc.exists) {
      throw Exception("Ce collier est déjà associé à un utilisateur.");
    }

    // 2️⃣ Ajouter le collier pour l'utilisateur dans sa sous-collection
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

    // 3️⃣ Ajouter le collier dans EndNode_user pour bloquer les doublons
    await _firestore.collection('EndNode_user').doc(collarId).set({
      'user': userEmail,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}