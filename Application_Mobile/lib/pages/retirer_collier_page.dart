import 'package:flutter/material.dart';
import 'package:youtube_tuto/backend/supprimer_collier.dart'; // Import backend service

class RetirerCollierPage extends StatefulWidget {
  const RetirerCollierPage({super.key});

  @override
  _RetirerCollierPageState createState() => _RetirerCollierPageState();
}

class _RetirerCollierPageState extends State<RetirerCollierPage>
    with SingleTickerProviderStateMixin {
  final SupprimerCollierService _collierService = SupprimerCollierService();
  String? selectedCollarName; // Selected collar name (doc.id)
  Map<String, String> collars = {}; // Collar name -> Collar ID
  bool isLoading = false;
  String? feedbackMessage;

  // Animation variables
  late AnimationController _animationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Fetch collars from Firebase
    _fetchCollars();
  }

  Future<void> _fetchCollars() async {
    setState(() {
      isLoading = true;
    });

    final fetchedCollars = await _collierService.fetchCollars(); // Fetch collar data
    setState(() {
      collars = fetchedCollars;
      isLoading = false;
    });
  }

  Future<void> _removeCollar(String collarName) async {
    setState(() {
      isLoading = true;
      feedbackMessage = null;
    });

    await _collierService.deleteCollar(collarName); // Delete collar from Firebase
    setState(() {
      collars.remove(collarName); // Remove from UI
      selectedCollarName = null;
      isLoading = false;
      feedbackMessage = "✅ Collier retiré avec succès.";
    });
  }

  Future<void> _showConfirmationDialog() async {
    if (selectedCollarName == null) {
      setState(() {
        feedbackMessage = "⚠️ Veuillez sélectionner un collier à retirer.";
      });
      return;
    }

    final collarId = collars[selectedCollarName] ?? "ID inconnu";

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: Text(
          "Voulez-vous vraiment retirer le collier ID: $collarId - $selectedCollarName ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Oui"),
          ),
        ],
      ),
    );

    if (result == true) {
      _removeCollar(selectedCollarName!);
    } else {
      setState(() {
        feedbackMessage = "❌ Suppression annulée.";
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Retirer Collier"),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              const Text(
                "Sélectionnez un collier à retirer",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Dropdown to select collar
              isLoading
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                value: selectedCollarName,
                items: collars.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text("${entry.value} - ${entry.key}"),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCollarName = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Collier",
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Remove button with animation
              GestureDetector(
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                onTap: _showConfirmationDialog,
                child: ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Retirer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Feedback message
              if (feedbackMessage != null)
                Text(
                  feedbackMessage!,
                  style: TextStyle(
                    fontSize: 16,
                    color: feedbackMessage!.contains("succès")
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
