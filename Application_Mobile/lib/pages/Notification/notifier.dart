import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_tuto/pages/Notification/notification_provider.dart';
import 'notification_provider.dart';
class NotifierPage extends StatefulWidget {
  const NotifierPage({Key? key}) : super(key: key);

  @override
  _NotifierPageState createState() => _NotifierPageState();
}

class _NotifierPageState extends State<NotifierPage> {
  @override
  void initState() {
    super.initState();
  }/*
  void _showClearNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Supprimer toutes les notifications"),
          content: Text("Voulez-vous vraiment effacer toutes les notifications ? Cette action est irréversible."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Fermer sans supprimer
              child: Text("Annuler", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final notificationProvider = context.read<NotificationProvider>();
                notificationProvider.clearAllNotifications();
                Navigator.pop(context);
              },
              child: Text("Supprimer", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }*/
  @override
  Widget build(BuildContext context) {
    final notifications = Provider.of<NotificationProvider>(context).notifications;

    // Organisation des notifications par date
    Map<String, List<Map<String, String>>> groupedNotifications = {};
    for (var notif in notifications) {
      String date = notif["date"]!;
      if (!groupedNotifications.containsKey(date)) {
        groupedNotifications[date] = [];
      }
      groupedNotifications[date]!.add(notif);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
       /*   actions: [
          IconButton(
            icon: Icon(Icons.delete_forever, color: Colors.red),
            tooltip: "Supprimer toutes les notifications",
            onPressed: () {
              _showClearNotificationsDialog(context);
            },
          ),
        ],*/
      ),
      body: notifications.isEmpty
          ? const Center(child: Text("Aucune alerte pour l'instant"))
          : ListView(
        children: groupedNotifications.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affichage de la date comme titre
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  entry.key, // Date en titre
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              //  Liste des notifications sous cette datee
              ...entry.value.map((notif) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.redAccent),
                  title: Text(
                    "${notif["time"]} - ${notif["message"]}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}
