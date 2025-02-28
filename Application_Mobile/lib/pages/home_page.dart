import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Pour les Toast
import 'infos_collier_page.dart';
import 'appairer_collier_page.dart';
import 'Notification/notifier.dart';
import 'retirer_collier_page.dart';
import 'compte_page.dart';
import 'parametres_page.dart';
import 'package:youtube_tuto/backend/login_page.dart';
import 'package:provider/provider.dart';
import 'package:youtube_tuto/pages/manager_field/Interface_modifier_champ.dart';
import 'package:youtube_tuto/pages/Notification/notification_provider.dart';
import 'package:youtube_tuto/pages/services/internet_checker.dart';

class HomePage extends StatefulWidget {
  final dynamic onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = true;
  late InternetService _internetService;
  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      //FirestoreNotificationListener().stopListening();
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginPage()),
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

  Future<void> _checkInitialConnection() async {
    bool isConnected = await _internetService.isConnected();
    setState(() {
      _isConnected = isConnected;
    });

    if (!isConnected) {
      _showNoInternetMessage();
    }
  }

  void _showNoInternetMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              "Vous êtes hors ligne",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _internetService = InternetService(onConnectionChange: (isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      if (!isConnected) {
        _showNoInternetMessage();
      }
    });

    _checkInitialConnection();
  }

  @override
  void dispose() {
    _internetService.dispose();
    super.dispose();
  }
  void _showWebNotificationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("📢 Notifications"),
          content: Text("🔔 Les notifications sont uniquement disponibles sur mobile."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // Extract the username from the email (remove @domain.com)
    String username = user?.email?.split('@').first ?? "Utilisateur";

    final notificationProvider = Provider.of<NotificationProvider>(context);
    int unreadCount = notificationProvider.unreadNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        backgroundColor: Colors.green,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => NotifierPage()));
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 5, // 🔹 Ajuste la position
                  top: 5,   // 🔹 Ajuste la position
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 12, minHeight: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],

      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
                image: const DecorationImage(
                  image: AssetImage('assets/icon/login_background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundImage: AssetImage('assets/icon/icon1.png'),
                        radius: 30.0,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Bienvenue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.orange),
              title: const Text('Infos collier'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfosColliersPage()),
                );
              },

            ),

            ListTile(
              leading: const Icon(Icons.add, color: Colors.teal),
              title: const Text('Appairer collier'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AppairerCollierPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove, color: Colors.red),
              title: const Text('Retirer collier'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RetirerCollierPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.indigo),
              title: const Text('Compte'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ComptePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ParametresPage()),
                );
              },
            ),


            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion'),
              onTap: () => logout(context), // Appelle la méthode de déconnexion
            ),

          ],
        ),
      ),
      body: const AddMainField(), // Default page is CartePage
    );
  }
}