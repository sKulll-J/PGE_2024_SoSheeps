import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  bool _hasNewNotification = false;
  bool get hasNewNotification => _hasNewNotification;
  //  Stocke la dernière date enregistrée pour chaque collier (mouton)
  Map<String, String> _lastRecordedDate = {};
  //  Stocke le dernier état "Sheep_out" pour chaque collier
  Map<String, bool> _lastSheepOutStatus = {};
  //  Stocke le dernier état "is_inside_polygon" pour chaque collier
  Map<String, bool> _lastInsidePolygonStatus = {};
  //  Stocke la dernière date enregistrée pour les changements Sheep_out
  Map<String, String> _lastRecordedDateSheepOut = {};
  //  Stocke le dernier niveau de batterie connu pour chaque collier
  Map<String, int> _lastBatteryStatus = {};

  //  Stocke la dernière date enregistrée pour la batterie
  Map<String, String> _lastRecordedDateBattery = {};

  void setNewNotification(bool value) async {
    _hasNewNotification = value;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('hasNewNotification', value);
  }
// Méthode pour supprimer toutes les notifications
  void clearAllNotifications() async {
    _notifications.clear();
    _unreadNotifications = 0;
    _hasNewNotification = false;

    notifyListeners();

    // Supprimer les notifications stockées localement
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('stored_notifications');
    await prefs.remove("sent_notifications");
  }

  Future<void> loadNotificationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _hasNewNotification = prefs.getBool('hasNewNotification') ?? false;
    notifyListeners();
  }
  Future<void> saveNotificationsLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encodedNotifications = jsonEncode(_notifications);
    await prefs.setString('stored_notifications', encodedNotifications);
  }

  Future<void> loadStoredNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedNotifications = prefs.getString('stored_notifications');

    if (storedNotifications != null) {
      List<dynamic> decodedList = jsonDecode(storedNotifications);
      _notifications = decodedList.map((notif) => Map<String, String>.from(notif)).toList();
    }

    notifyListeners();
  }

  int _unreadNotifications = 0;
  int get unreadNotifications => _unreadNotifications;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  String? _currentUserEmail;
  List<Map<String, String>> _notifications = [];

  List<Map<String, String>> get notifications => _notifications;


  void addNotification(String message, String date, String time) {
    String formattedMessage = "[$date] $time - $message";

    //  Vérifie si cette notification a déjà été envoyée
    bool alreadyExists = _notifications.any((notif) =>
    notif["date"] == date &&
        notif["time"] == time &&
        notif["message"] == message);

    if (!alreadyExists) {
      _notifications.insert(0, {
        "date": date,
        "time": time,
        "message": message,
      });

      _saveSentNotifications(); //  Sauvegarder les notifications envoyées
      notifyListeners();
    }
  }


  Future<void> _saveSentNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> notifList = _notifications.map((notif) => "${notif["date"]}|${notif["time"]}|${notif["message"]}").toList();
    await prefs.setStringList("sent_notifications", notifList);
  }
  Future<void> _loadSentNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? notifList = prefs.getStringList("sent_notifications");

    if (notifList != null) {
      _notifications = notifList.map((notif) {
        List<String> parts = notif.split("|");
        return {
          "date": parts[0],
          "time": parts[1],
          "message": parts[2],
        };
      }).toList();
    }
  }

  NotificationProvider() {
    //loadStoredNotifications(); //  Charger les notifications enregistrées
    _listenToFirestoreChanges(); //  Écouter les nouvelles notifications
    _loadSentNotifications();
  }

  Future<void> _saveNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> notifList = _notifications.map((notif) => "${notif["date"]}|${notif["time"]}|${notif["message"]}").toList();
    await prefs.setStringList("notifications", notifList);
  }

  Future<void> _loadNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? notifList = prefs.getStringList("notifications");

    if (notifList != null) {
      _notifications = notifList.map((notif) {
        List<String> parts = notif.split("|");
        return {
          "date": parts[0],
          "time": parts[1],
          "message": parts[2],
        };
      }).toList();
    }
  }

  void _listenToFirestoreChanges() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _firestore
        .collection("Utilisateurs")
        .doc(user.email)
        .collection("Colliers")
        .snapshots()
        .listen((snapshot) async {
      List<Map<String, String>> newNotifications = [];

      // Charger les notifications déjà enregistrées avant de traiter Firebase
      await _loadSentNotifications();

      for (var doc in snapshot.docs) {
        String collierName = doc.id;
        Map<String, dynamic> data = doc.data();

        //  Gestion des alertes de fuite et retour dans le champ
        if (data.containsKey("is_inside_polygon") && data.containsKey("received_at")) {
          bool isInside = data["is_inside_polygon"] as bool;
          String receivedAtRaw = data["received_at"] ?? "";

          try {
            DateTime receivedTime = DateTime.parse(receivedAtRaw).toLocal();

            String formattedDate = DateFormat('dd/MM/yyyy').format(receivedTime);
            String formattedTime = DateFormat('HH:mm').format(receivedTime);
            String message = isInside ? "$collierName est dans son champ" : "$collierName en fuite";

            // Vérifier si une notification identique (date + heure + message) existe déjà
            bool alreadyExists = _notifications.any((notif) =>
            notif["date"] == formattedDate &&
                notif["time"] == formattedTime &&
                notif["message"] == message);

            // Récupérer le dernier état connu et la dernière date enregistrée
            bool lastStatus = _lastInsidePolygonStatus[collierName] ?? !isInside; // Valeur opposée pour forcer la 1ère notification
            String lastRecordedDate = _lastRecordedDate[collierName] ?? "";

            // Ajouter une nouvelle notification uniquement si :
            // - L'état change (inside/outside)
            // - OU la date change (nouvelle journée)
            if (!alreadyExists && (lastStatus != isInside || lastRecordedDate != formattedDate)) {
              newNotifications.add({
                "date": formattedDate,
                "time": formattedTime,
                "message": message,
              });

              // 🔄 Mettre à jour le dernier état et la date enregistrée
              _lastInsidePolygonStatus[collierName] = isInside;
              _lastRecordedDate[collierName] = formattedDate;
            }
          } catch (e) {
            print("❌ Erreur lors de la conversion de received_at : $e");
          }
        }


        // Gestion des alertes de sortie/retour au troupeau dans le champ interdit
        if (data.containsKey("Sheep_out") && data.containsKey("received_at")) {
          bool sheepOut = data["Sheep_out"] as bool;
          String receivedAtRaw = data["received_at"] ?? "";

          try {
            DateTime receivedTime = DateTime.parse(receivedAtRaw).toLocal();

            String formattedDate = DateFormat('dd/MM/yyyy').format(receivedTime);
            String formattedTime = DateFormat('HH:mm').format(receivedTime);

            String message = sheepOut
                ? "⚠️ $collierName dans un champ interdit"
                : "✅ $collierName est sorti de champ interdit";

            // Vérifier l'existence de la notification
            bool alreadyExists = _notifications.any((notif) =>
            notif["date"] == formattedDate &&
                notif["time"] == formattedTime &&
                notif["message"] == message);

            // Récupérer les derniers états enregistrés
            bool lastStatus = _lastSheepOutStatus[collierName] ?? !sheepOut;
            String lastRecordedDate = _lastRecordedDateSheepOut[collierName] ?? "";

            if (!alreadyExists && (lastStatus != sheepOut || lastRecordedDate != formattedDate)) {
              newNotifications.add({
                "date": formattedDate,
                "time": formattedTime,
                "message": message,
              });
              // Affiche la notification dans la barre système
              NotificationService().showNotification(
                "Alerte collier",
                message,
                2, // Utilisez un ID unique pour cet événement
              );
              // Mettre à jour les derniers états
              _lastSheepOutStatus[collierName] = sheepOut;
              _lastRecordedDateSheepOut[collierName] = formattedDate;
            }
          } catch (e) {
            print("❌ Erreur traitement Sheep_out: $e");
          }
        }

        //  Gestion des alertes de batterie
        if (data.containsKey("battery_level") && data.containsKey("received_at")) {
          int batteryLevel = data["battery_level"] as int;
          String receivedAtRaw = data["received_at"] ?? "";

          try {
            DateTime receivedTime = DateTime.parse(receivedAtRaw).toLocal();

            String formattedDate = DateFormat('dd/MM/yyyy').format(receivedTime);
            String formattedTime = DateFormat('HH:mm').format(receivedTime);
            String batteryMessage = _getBatteryMessage(collierName, batteryLevel);

            // Récupérer le dernier niveau de batterie connu et la dernière date enregistrée
            int lastBatteryLevel = _lastBatteryStatus[collierName] ?? -1; // -1 pour forcer la première notification
            String lastRecordedDate = _lastRecordedDateBattery[collierName] ?? "";

            // Vérifier si la notification de batterie a déjà été envoyée
            bool alreadyExists = _notifications.any((notif) =>
            notif["date"] == formattedDate &&
                notif["time"] == formattedTime &&
                notif["message"] == batteryMessage);

            // Définition du seuil de variation significatif pour déclencher une alerte
            const int batteryThreshold = 10; // Notifier si la batterie change de 10% ou plus

            // Ajouter une nouvelle notification uniquement si :
            // - La batterie a changé significativement (par palier de 10%)
            // - OU la date a changé (nouvelle journée)
            if (!alreadyExists &&
                batteryMessage.isNotEmpty &&
                (lastBatteryLevel == -1 || (batteryLevel ~/ batteryThreshold) != (lastBatteryLevel ~/ batteryThreshold) || lastRecordedDate != formattedDate)) {
              newNotifications.add({
                "date": formattedDate,
                "time": formattedTime,
                "message": batteryMessage,
              });

              //  Mise à jour du dernier niveau de batterie et de la date enregistrée
              _lastBatteryStatus[collierName] = batteryLevel;
              _lastRecordedDateBattery[collierName] = formattedDate;
            }
          } catch (e) {
            print("❌ Erreur lors de la conversion de received_at pour batterie : $e");
          }
        }

      }

      //  Ajouter uniquement les notifications non existantes
      for (var notif in newNotifications) {
        addNotification(notif["message"]!, notif["date"]!, notif["time"]!);
      }

      _unreadNotifications = _notifications.length;
      notifyListeners();
    });
  }

  Future<void> _saveCollarStatus(Map<String, dynamic> collarStatus) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encodedStatus = jsonEncode(collarStatus);
    await prefs.setString('collar_status', encodedStatus);
  }

  Future<Map<String, dynamic>> _loadCollarStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? encodedStatus = prefs.getString('collar_status');

    if (encodedStatus != null) {
      return jsonDecode(encodedStatus);
    }

    return {};
  }

  void markNotificationsAsRead() {
    _unreadNotifications = 0;
    notifyListeners();
  }

  //  Gestion des messages de batterie
  String _getBatteryMessage(String collierName, int batteryLevel) {
    if (_lastInsidePolygonStatus.containsKey(collierName) && _lastInsidePolygonStatus[collierName] == batteryLevel) {
      return ""; // ✅ Ne renvoie pas de message si le niveau de batterie est inchangé
    }

    if (batteryLevel == 100) {
      return "🔋 [$collierName] : Batterie pleine";
    } else if (batteryLevel == 20) {
      return "⏳ [$collierName] : Il reste environ 20%";
    } else if (batteryLevel == 0) {
      return "⚠️ [$collierName] : ÉTEINT !";
    }
    return "";
  }
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

}