import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_tuto/pages/home_page.dart';
import 'auth_service.dart';
import 'signup_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 📡 Vérification connexion
import 'dart:math';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'auth_service.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String errorMessage = '';
  bool _isConnected = true; // Variable pour suivre la connexion
  bool _isSigningIn = false;
  User? _user; // 🔹 Variable pour stocker l'utilisateur connecté

  @override
  void initState() {
    super.initState();
    _checkInternetConnection(); // Vérifier la connexion au démarrage

    // 🔹 Écouter Firebase pour détecter les connexions sans actualiser la page
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        setState(() {
          _user = user;  // Met à jour l'état avec l'utilisateur actuel
        });
      }
    });
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });

    // Écoute des changements de connexion
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        // Si la liste contient autre chose que "none", alors on est connecté
        _isConnected = !results.contains(ConnectivityResult.none);
      });
    });
  }/*
  Future<void> sendVerificationEmail(String recipientEmail, String verificationCode) async {
    print("📩 Tentative d'envoi d'e-mail à $recipientEmail avec le code : $verificationCode");

    // Configuration du serveur SMTP Gmail
    final smtpServer = gmail('magody876@gmail.com', 'PGE 2024 SME UT3');

    final message = Message()
      ..from = Address('magody876@gmail.com', 'PGE 2024 SME UT3') // Expéditeur
      ..recipients.add(recipientEmail) // Destinataire
      ..subject = 'Votre code de vérification 🔐' // Objet du mail
      ..text = '''
Bonjour,

Votre code de connexion est : $verificationCode

Merci de l’utiliser pour valider votre connexion.

Cordialement,
L’équipe PGE 2024 SME UT3.
''';

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ E-mail envoyé avec succès : ${sendReport.toString()}');
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'e-mail : $e');
    }
  }*/

  // Fonction pour générer un code de 3 chiffres
  int _generateVerificationCode() {
    Random random = Random();
    return 100000 + random.nextInt(900000); // Code à 6 chiffres
  }

  Future<void> _sendVerificationCodeByEmail(String email, int code) async {
    final Email mail = Email(
      body: 'Votre code de vérification est : $code',
      subject: 'Code de vérification',
      recipients: [email],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(mail);
      print("📩 Email envoyé avec succès !");
    } catch (e) {
      print("❌ Erreur lors de l'envoi de l'email : $e");
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Réinitialiser le mot de passe",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Entrez votre adresse e-mail. Vous recevrez un lien pour réinitialiser votre mot de passe.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email, color: Colors.teal),
                  hintText: "Votre e-mail",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                String email = emailController.text.trim();
                if (email.isNotEmpty) {
                  await _resetPassword(email, context);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez entrer une adresse e-mail valide."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Envoyer"),
            ),
          ],
        );
      },
    );
  }
  Future<void> _resetPassword(String email, BuildContext context) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ Email de réinitialisation envoyé à $email",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Erreur : ${e.toString()}",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> login(BuildContext context) async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucune connexion Internet ! Vérifiez votre réseau."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    try {
      await FirebaseAuth.instance.signOut(); // Forcer la déconnexion
      final user = await _authService.signInWithEmailPassword(email, password);
      if (user != null) {
        await FirebaseAuth.instance.authStateChanges().first; // Force la mise à jour de l'état
        await saveUserToken(email);
        //FirestoreNotificationListener().startListening();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomePage(onThemeChanged: (bool value) {})),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );

      passwordController.clear();
    }
  }

  Future<void> saveUserToken(String userEmail) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      DocumentReference userDoc =
      FirebaseFirestore.instance.collection('Utilisateurs').doc(userEmail);

      await userDoc.set(
        {'FCM_token': token},
        SetOptions(merge: true),
      );
    }
  }
/*
  Future<void> _signInWithGoogle() async {
    if (!_isConnected) {
      _showSnackBar("❌ Pas de connexion Internet !", Colors.red);
      return;
    }

    setState(() => _isSigningIn = true);

    User? user;

    try {
      if (kIsWeb) {
        // 🔹 Google Sign-In pour le Web
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        // 🔹 Google Sign-In pour Mobile
        user = await _authService.signInWithGoogle();
        if (user != null) {
          // 🔹 Rafraîchir l'utilisateur Firebase pour le Web
          await Future.delayed(Duration(milliseconds: 500)); // Petite pause
          User? refreshedUser = FirebaseAuth.instance.currentUser; // Force la mise à jour
          setState(() {
            _user = refreshedUser; // Met à jour l'état sans actualiser la page
          });

          // 🔹 Générer un code de connexion
          int verificationCode = _generateVerificationCode();

          // 🔹 Envoyer le code par e-mail
          await sendVerificationEmail(user.email!, verificationCode.toString()).catchError((error) {
            _showSnackBar("❌ Échec d'envoi du code : ${error.toString()}", Colors.red);
            FirebaseAuth.instance.signOut(); // Annule l'authentification
          });

          // 🔹 Afficher la boîte de dialogue pour la vérification
          _showCodeVerificationDialog(user, verificationCode);
        }

      }

    } catch (e) {
      _showSnackBar("❌ Erreur : ${e.toString()}", Colors.red);
    }

    setState(() => _isSigningIn = false);
  }*/






  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed, //  Empêche qu'il sorte de l'écran
      ),
    );
  }


  void _showCodeVerificationDialog(User user, int correctCode) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit entrer un code
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Vérification du Code",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis, // Évite les dépassements
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Nous avons envoyé un code à votre adresse e-mail :",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 5),

                // ✅ Correction du dépassement en utilisant Wrap et MediaQuery
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        user.email!,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15),

                // Champ de saisie du code
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent, width: 1),
                  ),
                  child: TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Entrez le code",
                      border: InputBorder.none,
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Boutons Annuler / Valider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        FirebaseAuth.instance.signOut(); // Déconnecte si annulation
                      },
                      child: Text("Annuler", style: TextStyle(color: Colors.red, fontSize: 16)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        int enteredCode = int.tryParse(codeController.text) ?? 0;
                        if (enteredCode == correctCode) {
                          Navigator.pop(context);
                          _validateUserAccess(user); // ✅ Connexion validée !
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("❌ Code incorrect"), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      ),
                      child: Text("Valider", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Bouton Renvoyer le Code
                /*TextButton(
                  onPressed: () async {
                    int newVerificationCode = _generateVerificationCode();
                    await sendVerificationEmail(user.email!, newVerificationCode.toString());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("📩 Nouveau code envoyé !"), backgroundColor: Colors.green),
                    );
                  },
                  child: Text(
                    "Renvoyer le code",
                    style: TextStyle(fontSize: 16, color: Colors.blueAccent, decoration: TextDecoration.underline),
                  ),
                ),*/
              ],
            ),
          ),
        );
      },
    );
  }


  void _validateUserAccess(User user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage(onThemeChanged: (bool value) {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/icon/login_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: _isConnected
                ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Connectez-vous à votre compte',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: 'Adresse e-mail',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                      const Icon(Icons.email, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: 'Mot de passe',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                      const Icon(Icons.lock, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => login(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 64.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                 /* ElevatedButton.icon(
                    onPressed: _signInWithGoogle, // Appeler _signInWithGoogle ici
                    icon: Image.asset("assets/icon/Google.png", height: 24), // Ajoute une icône Google
                    label: const Text("Se connecter avec Google"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),*/

                  const SizedBox(height: 16),
                  const SizedBox(height: 16),

                  //  Bouton "Mot de passe oublié ?" bien stylé
                  TextButton(
                    onPressed: () {
                      _showForgotPasswordDialog(context);
                    },
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline, // Un petit soulignement pour le style
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  //  Bouton "Créer un compte" déjà existant
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                      );
                    },
                    child: const Text(
                      "Vous n'avez pas de compte ? Créez-en un",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                ],
              ),
            )
                : Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    "Pas de connexion Internet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Veuillez vérifier votre connexion réseau et réessayer.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _checkInternetConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      "Réessayer",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
