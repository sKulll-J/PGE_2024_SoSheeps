import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupprimerCollierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user email
  String get _userEmail => _auth.currentUser?.email ?? '';

  // Fetch all collars (Name + ID)
  Future<Map<String, String>> fetchCollars() async {
    if (_userEmail.isEmpty) return {};

    try {
      final snapshot = await _firestore
          .collection('Utilisateurs')
          .doc(_userEmail)
          .collection('Colliers')
          .get();

      if (snapshot.docs.isEmpty) {
        return {};
      }

      Map<String, String> collars = {};
      for (var doc in snapshot.docs) {
        final collarId = doc.data().containsKey('collar_id') ? doc['collar_id'].toString() : 'Unknown ID';
        collars[doc.id] = collarId; // doc.id is the collar name
      }
      return collars;
    } catch (e) {
      print("🔥 Error fetching collars: $e");
      return {};
    }
  }

  // Delete a collar
  Future<void> deleteCollar(String collarName) async {
    if (_userEmail.isEmpty) return;

    try {
      await _firestore
          .collection('Utilisateurs')
          .doc(_userEmail)
          .collection('Colliers')
          .doc(collarName)
          .delete();
    } catch (e) {
      print("🔥 Error deleting collar: $e");
    }
  }
}
