import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 🔥 Connexion avec Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Utilisateur a annulé la connexion
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("❌ Erreur lors de la connexion Google: $e");
      return null;
    }
  }


  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase authentication errors
      if (e.code == 'user-not-found') {
        throw Exception(
            'Aucun compte trouvé pour cet e-mail. Veuillez vérifier l\'adresse e-mail ou créer un compte.');
      } else if (e.code == 'wrong-password') {
        throw Exception(
            'Le mot de passe est incorrect. Veuillez réessayer.');
      } else if (e.code == 'invalid-email') {
        throw Exception(
            'Adresse e-mail invalide. Veuillez entrer une adresse valide.');
      } else if (e.code == 'user-disabled') {
        throw Exception(
            'Ce compte utilisateur a été désactivé. Veuillez contacter le support.');
      } else {
        throw Exception('Erreur inconnue : ${e.message}');
      }
    } catch (e) {
      throw Exception('Une erreur est survenue : ${e.toString()}');
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('Utilisateurs')
          .doc(userCredential.user!.email)
          .set({
        'email': email,
        'createdAt': DateTime.now(),
      });

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(
            'Cet e-mail est déjà utilisé. Veuillez en choisir un autre.');
      } else if (e.code == 'weak-password') {
        throw Exception(
            'Le mot de passe est trop faible. Veuillez utiliser un mot de passe plus sécurisé.');
      } else if (e.code == 'invalid-email') {
        throw Exception(
            'Adresse e-mail invalide. Veuillez entrer une adresse valide.');
      } else {
        throw Exception('Erreur inconnue : ${e.message}');
      }
    } catch (e) {
      throw Exception('Une erreur est survenue : ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Get the current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
