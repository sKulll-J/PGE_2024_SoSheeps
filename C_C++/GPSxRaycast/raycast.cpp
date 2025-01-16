#include <iostream>
#include <vector>
#include <cmath>

using namespace std;

// Structure pour les coordonnées GPS
struct CoordGPS {
    double latitude;
    double longitude;
};

// Structure pour les zones
struct Zone {
    vector<CoordGPS> sommets;
};

// Fonction pour vérifier si un point est dans un polygone
bool estDansPolygone(const CoordGPS& point, const vector<CoordGPS>& polygone) {
    int n = polygone.size();
    bool dedans = false;
    double epsilon = 1e-9;

    for (int i = 0, j = n - 1; i < n; j = i++) {
        if (std::fabs(point.latitude - polygone[i].latitude) < epsilon && 
            std::fabs(point.longitude - polygone[i].longitude) < epsilon) 
        {
            return true;
        }

        if ((polygone[i].longitude > point.longitude) != (polygone[j].longitude > point.longitude) &&
            (point.latitude < (polygone[j].latitude - polygone[i].latitude) * (point.longitude - polygone[i].longitude) / (polygone[j].longitude - polygone[i].longitude) + polygone[i].latitude)) 
        {
            dedans = !dedans;
        }
    }

    return dedans;
}

int main() {
    // 4 coordonnées GPS des sommets de la salle H0
    Zone zone;
    CoordGPS sommet1 = {43.559409, 1.469427};             
    CoordGPS sommet2 = {43.559340, 1.469288}; 
    CoordGPS sommet3 = {43.559185, 1.469443}; 
    CoordGPS sommet4 = {43.559257, 1.469582}; 
    
    zone.sommets.push_back(sommet1); 
    zone.sommets.push_back(sommet2); 
    zone.sommets.push_back(sommet3);
    zone.sommets.push_back(sommet4);

    // Définir un point à tester
    CoordGPS point_out = {43.559233, 1.469134}; // point en dehors
    CoordGPS point_in = {43.559300, 1.469433};  // point dedans

    // Tester si le point est dans le polygone
    if (estDansPolygone(point_in, zone.sommets)) {
        cout <<"\n---\nLe point est dans le polygone.\n---\n " << endl;
    } else {
        cout << "\n---\nLe point n'est pas dans le polygone.\n---\n" << endl;
    }

    return 0;
}
