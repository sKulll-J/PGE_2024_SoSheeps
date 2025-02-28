import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MyLocationButton extends StatelessWidget {
  final MapController mapController;
  final double zoomLevel;
  final void Function(LatLng) onPositionUpdate; // Callback pour informer le parent

  const MyLocationButton({
    Key? key,
    required this.mapController,
    required this.onPositionUpdate,
    this.zoomLevel = 18.0,
  }) : super(key: key);

  Future<void> _goToMyLocation(BuildContext context) async {
    // Vérifier et demander les permissions de localisation
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permission de localisation refusée."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Récupérer la position actuelle
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.lowest,
    );

    final LatLng myPosition = LatLng(position.latitude, position.longitude);

    // Centrer la carte sur la position de l'utilisateur
    mapController.move(myPosition, zoomLevel);

    // Notifier le parent de la nouvelle position
    onPositionUpdate(myPosition);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "btnMyLocation",
      onPressed: () => _goToMyLocation(context),
      child: const Icon(Icons.my_location),
      tooltip: 'Afficher ma position',
    );
  }
}
