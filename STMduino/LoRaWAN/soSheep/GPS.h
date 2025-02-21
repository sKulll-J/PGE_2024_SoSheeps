#pragma once
#include "config.h"
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
    {43.558980, 1.469207},
    {43.559507, 1.468677},
    {43.559810, 1.469402},
    {43.559326, 1.470138}
  },
  4 // Nb sommets
};

void GPS_init();
bool estDansPolygone(const CoordGPS& point, const CoordGPS* polygone, int vertexCount);
void locate(sLonLat_t *lat, sLonLat_t *lon);
uint8_t get_nbSat();