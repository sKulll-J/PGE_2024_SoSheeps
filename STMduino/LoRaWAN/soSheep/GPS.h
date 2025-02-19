#pragma once
#include <DFRobot_GNSS.h>
#include <math.h>

// Nb sommets maximum pour le polygone
#define MAX_VERTICES 10

// Structure pour les coordonnées GPS
struct CoordGPS {
  double latitude;
  double longitude;
};

// Structure pour les zones
struct Zone {
  CoordGPS sommets[MAX_VERTICES];
  int vertexCount;
};

// Define the constant Zone with predefined coordinates
const Zone predefinedZone = {
  {  // ex: salle H0
    {43.559409, 1.469427},
    {43.559340, 1.469288},
    {43.559185, 1.469443},
    {43.559257, 1.469582}
  },
  4 // Nb sommets
};

void GPS_init();
bool estDansPolygone(const CoordGPS& point, const CoordGPS* polygone, int vertexCount);
void locate(sLonLat_t *lat, sLonLat_t *lon);
