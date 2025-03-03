#include "GPS.h"

// GPS instanciation
DFRobot_GNSS_I2C gnss(&Wire ,GNSS_DEVICE_ADDR);

void GPS_init(){
  Wire.setSDA(PB9);
  Wire.setSCL(PB8);
  Wire.begin(); 
  if(!gnss.begin()){
    #if DEBUG
      Serial.println(F("no GPS device\n"));
    #endif
  }
  else {
    #if DEBUG
      Serial.println(F("GPS ready\n"));
      //gnss.enablePower();
    #endif
  }
}

bool estDansPolygone(const CoordGPS& point, const CoordGPS* polygone, int vertexCount) {
  bool dedans = false;
  double epsilon = 1e-9;

  for (int i = 0, j = vertexCount - 1; i < vertexCount; j = i++) {
    if (fabs(point.latitude  - polygone[i].latitude ) < epsilon && 
        fabs(point.longitude - polygone[i].longitude) < epsilon) 
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

void locate(sLonLat_t *lat, sLonLat_t *lon){
  *lat = gnss.getLat();
  *lon = gnss.getLon();
}

uint8_t get_nbSat(){
  return gnss.getNumSatUsed(); 
}

#if DEBUG
void test0_position(){
  double lat = 43.5592760;
  double lon = 1.4694470;

  CoordGPS Point {
    lat, lon
  };
  if ( estDansPolygone(Point, predefinedZone.sommets, predefinedZone.vertexCount) == 1 )
    Serial.println(F("inside"));
  else 
    Serial.println(F("outside"));
}
#endif
