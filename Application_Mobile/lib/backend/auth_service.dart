import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 🔥 Connexion avec Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      // 1) Essayer une connexion "légère" (silencieuse équivalente)
      final GoogleSignInAccount? lightUser =
      await _googleSignIn.attemptLightweightAuthentication(reportAllExceptions: false);

      if (lightUser != null) {
        // connecté silencieusement
        return lightUser;
      }

      // 2) Si la tentative légère n'a pas donné d'utilisateur, lancer le flux interactif.
      //    ATTENTION : sur certaines plateformes l'appel à authenticate() doit être effectué
      //    *dans* un user gesture (bouton press). Vérifie authorizationRequiresUserInteraction().
      final bool needsUserGesture = _googleSignIn.authorizationRequiresUserInteraction();

      if (needsUserGesture) {
        // Si tu appelles depuis un handler de bouton, c'est OK d'appeler authenticate ici.
        // Exemple : onPressed: () async { await signInWithGoogle(); }
      }

      // Lance le flux interactif (équivalent moderne de l'ancien signIn()).
      final GoogleSignInAccount user = await _googleSignIn.authenticate(
        scopeHint: <String>['email', 'profile'], // ajoute d'autres scopes si besoin
      );

      return user;
    } catch (error) {
      print("Erreur lors de la connexion Google : $error");
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
