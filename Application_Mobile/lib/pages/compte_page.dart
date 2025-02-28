import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ComptePage extends StatefulWidget {
  const ComptePage({Key? key}) : super(key: key);

  @override
  _ComptePageState createState() => _ComptePageState();
}

class _ComptePageState extends State<ComptePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isUpdating = false;
  bool _isPasswordVisible = false;
  bool _isCurrentPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final User? user = FirebaseAuth.instance.currentUser;

  Future<bool> reauthenticateUser() async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPasswordController.text,
      );
      await user!.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Mot de passe actuel incorrect.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    }
  }

  Future<void> updatePassword() async {
    if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Veuillez remplir tous les champs.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      Fluttertoast.showToast(
        msg: "Le mot de passe doit contenir au moins 6 caractères.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(
        msg: "Les mots de passe ne correspondent pas.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isUpdating = true);

    if (!await reauthenticateUser()) {
      setState(() => _isUpdating = false);
      return;
    }

    try {
      await user!.updatePassword(_passwordController.text);
      Fluttertoast.showToast(
        msg: "Mot de passe mis à jour avec succès !",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      _currentPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Erreur : $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Mon Compte", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView( //  Ajout du défilement
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20), //  Ajustement du clavier
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: Icon(Icons.person, size: 90, color: Colors.green)),
                        const SizedBox(height: 20),

                        /// 🔹 Email de l'utilisateur
                        const Text(
                          "Adresse Email",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email, color: Colors.green),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  user?.email ?? "Non défini",
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis, //  Empêche le débordement
                                  softWrap: false,
                                ),
                              ),

                            ],
                          ),

                        ),
                        const SizedBox(height: 20),

                        /// 🔹 Champs de texte stylisés
                        buildPasswordField("Mot de passe actuel", _currentPasswordController, _isCurrentPasswordVisible, () {
                          setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible);
                        }),
                        const SizedBox(height: 20),
                        buildPasswordField("Nouveau mot de passe", _passwordController, _isPasswordVisible, () {
                          setState(() => _isPasswordVisible = !_isPasswordVisible);
                        }),
                        const SizedBox(height: 20),
                        buildPasswordField("Confirmez le mot de passe", _confirmPasswordController, _isConfirmPasswordVisible, () {
                          setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                        }),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔹 Bouton stylisé
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isUpdating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Modifier le mot de passe",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Fonction pour construire un champ de mot de passe stylisé
  Widget buildPasswordField(String label, TextEditingController controller, bool isVisible, VoidCallback toggleVisibility) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: toggleVisibility,
            ),
          ),
        ),
      ],
    );
  }
}
