#include "GPS.h"

// GPS instanciation
DFRobot_GNSS_I2C gnss(&Wire ,GNSS_DEVICE_ADDR);

void GPS_init(){
  Wire.setSDA(PB9);
  Wire.setSCL(PB8);
  Wire.begin(); 
  if(!gnss.begin()){
    Serial.println(F("no GPS device\n"));
  }
  else {
    Serial.println(F("GPS ready\n"));
    gnss.enablePower();
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

// Function to encode double coordinates into a uint8_t array
void encodeCoordinates(double latitude, double longitude, uint8_t* payload) {
  int32_t lat = latitude * 1e7;
  int32_t lon = longitude * 1e7;

  // Encode latitude into the payload array (4 bytes)
  payload[0] = (lat >> 24) & 0xFF;
  payload[1] = (lat >> 16) & 0xFF;
  payload[2] = (lat >> 8) & 0xFF;
  payload[3] = lat & 0xFF;

  // Encode longitude into the payload array (4 bytes)
  payload[4] = (lon >> 24) & 0xFF;
  payload[5] = (lon >> 16) & 0xFF;
  payload[6] = (lon >> 8) & 0xFF;
  payload[7] = lon & 0xFF;

  // Print the payload for verification
  Serial.print("Payload: ");
  for (int i = 0; i < 8; i++) {
    Serial.print(payload[i], HEX);
    if (i < 7) Serial.print(" ");
  }
  Serial.println();
}

void locate(sLonLat_t *lat, sLonLat_t *lon){
  *lat = gnss.getLat();
  *lon = gnss.getLon();
}

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