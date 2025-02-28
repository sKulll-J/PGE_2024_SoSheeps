import 'package:flutter/material.dart';
import 'package:youtube_tuto/backend/ajouter_collier.dart';

class AppairerCollierPage extends StatefulWidget {
  const AppairerCollierPage({super.key});

  @override
  _AppairerCollierPageState createState() => _AppairerCollierPageState();
}

class _AppairerCollierPageState extends State<AppairerCollierPage> {
  final TextEditingController _collarNameController = TextEditingController();
  final TextEditingController _collarIdController = TextEditingController();

  String? selectedAnimalType;
  String? collarNameErrorMessage;
  String? collarIdErrorMessage;

  @override
  void initState() {
    super.initState();
  }

  /// Ajoute un collier après validation
  void _addCollar() async {
    final collarName = _collarNameController.text.trim();
    final collarId = _collarIdController.text.trim();

    if (collarName.isEmpty || collarId.isEmpty || selectedAnimalType == null) {
      setState(() {
        collarNameErrorMessage = collarName.isEmpty ? "Champ requis." : null;
        collarIdErrorMessage = collarId.isEmpty ? "Champ requis." : null;
      });
      return;
    }

    try {
      await AjouterCollierBackend.addCollar(
        collarName: collarName,
        collarId: collarId,
        animalType: selectedAnimalType!,
      );

      setState(() {
        collarNameErrorMessage = null;
        collarIdErrorMessage = null;
        selectedAnimalType = null;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Succès", style: TextStyle(color: Colors.green)),
          content: const Text("Collier ajouté avec succès !"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _collarNameController.clear();
                _collarIdController.clear();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _collarNameController.dispose();
    _collarIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appairer Collier", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ajouter un nouveau collier",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 20),

            // Nom du collier
            TextField(
              controller: _collarNameController,
              decoration: InputDecoration(
                labelText: "Nom du collier",
                labelStyle: const TextStyle(color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green, width: 2.0),
                  borderRadius: BorderRadius.circular(10),
                ),
                errorText: collarNameErrorMessage,
              ),
            ),
            const SizedBox(height: 20),

            // ID du collier
            TextField(
              controller: _collarIdController,
              decoration: InputDecoration(
                labelText: "ID du collier",
                labelStyle: const TextStyle(color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green, width: 2.0),
                  borderRadius: BorderRadius.circular(10),
                ),
                errorText: collarIdErrorMessage,
              ),
            ),
            const SizedBox(height: 20),

            // Sélection du type d'animal
            DropdownButtonFormField<String>(
              value: selectedAnimalType,
              decoration: InputDecoration(
                labelText: "Type d'animal",
                labelStyle: const TextStyle(color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green, width: 2.0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(value: "Chien", child: Text("Chien")),
                DropdownMenuItem(value: "Mouton", child: Text("Mouton")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedAnimalType = value;
                });
              },
              hint: const Text("Sélectionner un type"),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            const SizedBox(height: 20),

            // Bouton Ajouter
            Center(
              child: ElevatedButton(
                onPressed: _addCollar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Ajouter",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}