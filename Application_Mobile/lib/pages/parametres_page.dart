import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/login_page.dart';
import 'compte_page.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({Key? key}) : super(key: key);

  @override
  _ParametresPageState createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      //FirestoreNotificationListener().stopListening();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Erreur lors de la déconnexion : $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _goToCompte() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ComptePage()));
  }

  void _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'PGE.2024.SME.UT3@gmail.com',
      query:
      'subject=${Uri.encodeComponent("Demande de support - Mon Application")}',
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: "Impossible d'ouvrir l'application e-mail.");
    }
  }

  // Option "Aide" : ouvre une page dédiée présentant toutes les instructions d'utilisation
  void _goToHelp() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AidePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Évite le débordement
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Paramètres",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        centerTitle: true,
        elevation: 5,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Center(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings, size: 90, color: Colors.green),
                  const SizedBox(height: 20),

                  /// 🛡️ Modifier le mot de passe
                  _buildSettingTile(
                    icon: Icons.lock_outline,
                    title: "Modifier le mot de passe",
                    onTap: _goToCompte,
                  ),

                  /// 📩 Support / Contact par e-mail
                  _buildSettingTile(
                    icon: Icons.email_outlined,
                    title: "Support & Contact",
                    onTap: _sendEmail,
                  ),

                  /// ℹ️ À propos de l'application
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: "À propos de l'application",
                    onTap: () => _showAboutDialog(context),
                  ),

                  /// ❓ Aide
                  _buildSettingTile(
                    icon: Icons.help_outline,
                    title: "Aide",
                    onTap: _goToHelp,
                  ),

                  /// 🔑 Déconnexion
                  _buildSettingTile(
                    icon: Icons.logout,
                    title: "Déconnexion",
                    onTap: () => logout(context),
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: color ?? Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87),
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios,
                  size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("À propos de l'application",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
              "Cette application a été développée avec Flutter.\n\n"
                  "Elle utilise des technologies modernes telles que Firebase, Cloud Firestore, "
                  "et Firebase Auth pour offrir une expérience utilisateur fluide et réactive. \n\n"
                  "L'application permet de gérer vos colliers connectés, de visualiser la carte en temps réel, "
                  "et de gérer vos champs et informations personnelles de manière intuitive."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
              const Text("Fermer", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Déconnexion"),
          content:
          const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Déconnexion",
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ?? false;
  }
}

// Nouvelle page "Aide" présentant toutes les fonctionnalités de l'application
class AidePage extends StatelessWidget {
  const AidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aide"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bienvenue dans l'aide de l'application",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Cette application vous permet de gérer vos colliers et vos champs de manière intuitive. Voici un guide détaillé pour vous aider à utiliser toutes les fonctionnalités :",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              "Infos Colliers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.pets, color: Colors.green),
              title: const Text("Infos Colliers"),
              subtitle: const Text(
                  "Accédez à la section 'Infos Colliers' pour consulter la position, le niveau de batterie, l'ID et la dernière mise à jour de vos colliers. Vous pouvez également renommer vos colliers directement depuis cette interface."),
            ),
            const Divider(),
            const Text(
              "Modifier Champ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.green),
              title: const Text("Modifier Champ"),
              subtitle: const Text(
                  "Dans la section 'Modifier Champ', vous pouvez ajouter, renommer, modifier le type, exporter ou importer vos champs pour organiser et gérer efficacement vos zones."),
            ),
            const Divider(),
            const Text(
              "Ajouter / Appairer Collier",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.green),
              title: const Text("Ajouter / Appairer Collier"),
              subtitle: const Text(
                  "Utilisez cette option pour ajouter un nouveau collier à votre compte. Les informations saisies seront vérifiées avant l'ajout."),
            ),
            const Divider(),
            const Text(
              "Retirer Collier",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.green),
              title: const Text("Retirer Collier"),
              subtitle: const Text(
                  "Supprimez un collier de votre compte en le sélectionnant dans la liste et en confirmant l'opération."),
            ),
            const Divider(),
            const Text(
              "Mon Compte",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.green),
              title: const Text("Mon Compte"),
              subtitle: const Text(
                  "Accédez à la section 'Mon Compte' pour mettre à jour votre mot de passe et gérer vos informations personnelles."),
            ),
            const Divider(),
            const Text(
              "Carte",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.green),
              title: const Text("Carte"),
              subtitle: const Text(
                  "Visualisez la position de vos colliers en temps réel et consultez des informations comme le niveau de batterie et la dernière mise à jour sur la page 'Carte'."),
            ),
            const SizedBox(height: 16),
            const Text(
              "Pour toute question supplémentaire, veuillez contacter le support via l'option 'Support & Contact'.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
