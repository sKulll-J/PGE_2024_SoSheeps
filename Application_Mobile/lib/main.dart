import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:youtube_tuto/firebase_options.dart';
import 'package:youtube_tuto/pages/Notification/notification_provider.dart';
import 'backend/login_page.dart';
import 'pages/home_page.dart';
import 'package:youtube_tuto/pages/Notification/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_tuto/pages/Notification/foreground_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 Notification reçue en arrière-plan (app fermée) : ${message.notification?.title}");

  NotificationService().showNotification(
    message.notification?.title ?? "Nouvelle notification",
    message.notification?.body ?? "",
    0, // ✅ Ajouter un ID
  );

}

Future<void> _requestPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ Autorisation de notifications accordée.");
  } else {
    print("❌ Autorisation de notifications refusée.");
  }
}

// Fonction pour forcer la déconnexion au premier lancement
Future<void> checkFirstLaunch() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  if (isFirstLaunch) {
    await FirebaseAuth.instance.signOut();
    await prefs.setBool('isFirstLaunch', false);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Démarrer le foreground service dès qu'un utilisateur est connecté
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      initializeService();
    }
  });
  //await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  //  Activer le mode hors ligne Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // ✅ Stocke les données localement
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().init();
  await checkFirstLaunch();

  FirebaseMessaging.instance.getToken().then((token) {
    print("🔑 Token FCM: $token");
  });

  runApp(
    FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (context) => NotificationProvider()),
            ],
            child: const MyApp(),
          );
        }
        return const CircularProgressIndicator();
      },
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Variable globale pour le mode sombre
  bool _isDarkMode = false;
  User? _currentUser;

  // Callback pour mettre à jour le thème
  void _updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  // Vérifier si un utilisateur est déjà connecté
  void _checkUserStatus() {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      //FirestoreNotificationListener().startListening(); // 🔥 Redémarre l'écoute
    }
    setState(() {});
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Notification reçue en avant-plan : ${message.notification?.title}");
      NotificationService().showNotification(
        message.notification?.title ?? "Nouvelle notification",
        message.notification?.body ?? "",
        1, // ✅ Ajouter un ID unique
      );

    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 L'utilisateur a cliqué sur la notification.");
    });
  }

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _setupFirebaseMessaging();
    _checkUserStatus();

    // Charger l'état des notifications
    Provider.of<NotificationProvider>(context, listen: false).loadNotificationStatus();  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System On Sheep',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // Démarrer l'écoute des notifications pour l'utilisateur connecté
          //FirestoreNotificationListener().startListening();
          return HomePage(onThemeChanged: (bool value) {});
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
