import 'dart:async';
import 'dart:io'; // 📡 Pour vérifier la connexion Internet
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ Variables globales pour éviter les répétitions
Map<String, bool> lastIsInsidePolygon = {};
Map<String, String> lastBatteryStatus = {};
bool wasOffline = false; //  Suivi du statut de connexion

StreamSubscription<QuerySnapshot>? _foregroundSubscription;
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
String? currentUserEmail;
Timer? _internetCheckTimer; //  Timer pour surveiller la connexion

// ✅ Vérifier la connexion Internet
Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    // 1️⃣ Démarre le service foreground immédiatement
    service.setAsForegroundService();

    // 2️⃣ Configure la notification immédiatement
    service.setForegroundNotificationInfo(
      title: "SOSheep Service",
      content: "Le service de localisation est actif",
    );
    print("service démaré");
  }
  await Firebase.initializeApp();

  print("app inisialized");
  // 📡 Vérification de la connexion Internet toutes les 5 secondes
  _internetCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    bool isConnected = await hasInternetConnection();
    if (!isConnected && !wasOffline) {
      wasOffline = true; // Marque l'état hors ligne
      showNotification("🚨 Problème de connexion", "Vous êtes hors ligne !");
    } else if (isConnected && wasOffline) {
      wasOffline = false; // Marque le retour en ligne
      showNotification("✅ Connexion rétablie", "Vous êtes de nouveau en ligne !");
    }
  });

  // 🔥 Écoute les changements d'utilisateur
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    bool isConnected = await hasInternetConnection();
    if (!isConnected) {
      showNotification("🚨 Problème de connexion", "Vous êtes hors ligne !");
    }

    if (user != null && user.email != currentUserEmail) {
      print("✅ Changement d'utilisateur détecté : ${user.email}");
      currentUserEmail = user.email;
      startFirestoreListener(currentUserEmail!);
    } else if (user == null) {
      print("❌ Aucun utilisateur connecté, arrêt de l'écoute Firestore.");
      currentUserEmail = null;
      stopFirestoreListener();
    }
  });
}

// 📡 Démarrer l'écoute Firestore uniquement si Internet est actif
void startFirestoreListener(String userEmail) async {
  bool isConnected = await hasInternetConnection();
  if (!isConnected) {
    showNotification("🚨 Aucune connexion Internet", "Le suivi des colliers est désactivé !");
    return;
  }

  _foregroundSubscription?.cancel();

  print("📡 Démarrage de l'écoute Firestore pour : $userEmail");
  _foregroundSubscription = FirebaseFirestore.instance
      .collection("Utilisateurs")
      .doc(userEmail)
      .collection("Colliers")
      .snapshots()
      .listen((snapshot) async {
    for (var doc in snapshot.docs) {
      final String collierId = doc.id;
      final data = doc.data();

      // Si les deux variables sont présentes
      if (data.containsKey("is_inside_polygon") && data.containsKey("Sheep_out") && data.containsKey("received_at")) {
        final bool isInside = data["is_inside_polygon"] as bool;
        final bool sheepOut = data["Sheep_out"] as bool;
        // Si les deux sont fausses, prioriser is_inside_polygon
        if (!isInside && !sheepOut) {
          if (!lastIsInsidePolygon.containsKey(collierId) || lastIsInsidePolygon[collierId] != isInside) {
            lastIsInsidePolygon[collierId] = isInside;
            String message = "🚨 Collier $collierId en fuite !"; // is_inside_polygon false => fuite
            showNotification("Alerte collier", message);
          }
        } else {
          // Sinon, traitez chacune séparément
          // Traitement de is_inside_polygon
          if (!lastIsInsidePolygon.containsKey(collierId) || lastIsInsidePolygon[collierId] != isInside) {
            lastIsInsidePolygon[collierId] = isInside;
            String message = isInside
                ? "✅ Collier $collierId est dans son champ"
                : "🚨 Collier $collierId en fuite !";
            showNotification("Alerte collier", message);
          }
          // Traitement de Sheep_out
          String receivedAtRaw = data["received_at"] ?? "";
          DateTime receivedTime = DateTime.tryParse(receivedAtRaw)?.toLocal() ?? DateTime.now();
          // Ici, vous pouvez décider d'afficher la notification Sheep_out si elle apporte une information différente
          String sheepMessage = sheepOut
              ? "⚠️ Collier $collierId dans un champ interdit"
              : "✅ Collier $collierId est sorti de champ interdit";
          showNotification("Alerte Sheep_out", sheepMessage);
        }
      }
      // Si seule is_inside_polygon est présente
      else if (data.containsKey("is_inside_polygon")) {
        final bool isInside = data["is_inside_polygon"] as bool;
        if (!lastIsInsidePolygon.containsKey(collierId) || lastIsInsidePolygon[collierId] != isInside) {
          lastIsInsidePolygon[collierId] = isInside;
          String message = isInside
              ? "✅ Collier $collierId est dans son champ"
              : "🚨 Collier $collierId en fuite !";
          showNotification("Alerte collier", message);
        }
      }
      // Si seule Sheep_out est présente (avec received_at)
      else if (data.containsKey("Sheep_out") && data.containsKey("received_at")) {
        final bool sheepOut = data["Sheep_out"] as bool;
        String receivedAtRaw = data["received_at"] ?? "";
        DateTime receivedTime = DateTime.tryParse(receivedAtRaw)?.toLocal() ?? DateTime.now();
        String message = sheepOut
            ? "⚠️ Collier $collierId dans un champ interdit"
            : "✅ Collier $collierId est sorti de champ interdit";
        showNotification("Alerte Sheep_out", message);
      }

      // ⚡ Gestion des alertes batterie
      if (data.containsKey("battery_level")) {
        final int batteryLevel = data["battery_level"] as int;
        String batteryMessage = _getBatteryMessage(collierId, batteryLevel);
        if (batteryMessage.isNotEmpty) {
          showNotification("État de la batterie", batteryMessage);
        }
      }
    }
  }, onError: (error) {
    showNotification("🚨 Erreur Firestore", "Impossible de récupérer les données !");
  });
}



// 🛑 Arrêter l'écoute Firestore
void stopFirestoreListener() {
  _foregroundSubscription?.cancel();
  _foregroundSubscription = null;
}

// 🔔 Afficher une notification locale
void showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'collier_channel_id',
    'Collier Notifications',
    channelDescription: 'Notifications liées aux colliers',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
}

// 🔋 Gestion des alertes batterie
String _getBatteryMessage(String collierId, int batteryLevel) {
  String? status;
  if (batteryLevel == 100) {
    status = "🔋 Collier $collierId : Batterie pleine";
  } else if (batteryLevel == 20) {
    status = "⏳ Collier $collierId : Il reste 20%";
  } else if (batteryLevel == 0) {
    status = "⚠️ Collier $collierId : ÉTEINT !";
  } else {
    return "";
  }
  if (!lastBatteryStatus.containsKey(collierId) || lastBatteryStatus[collierId] != status) {
    lastBatteryStatus[collierId] = status;
    return status;
  }
  return "";
}

//  Initialiser le service en arrière-plan
Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.location, AndroidForegroundType.remoteMessaging],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  service.startService();
}

