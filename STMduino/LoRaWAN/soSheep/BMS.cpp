#include "BMS.h"

// BMS instanciation
OneWire oneWire(ONE_WIRE_BUS);
DS2438 bm(&oneWire);

float tension_tableau[nb_points] = {4.20, 4.00, 3.70, 3.30, 2.80, 2.50};
float soc_tableau[nb_points] = {100, 80, 50, 20, 5, 0};

// initialization function
void BMS_init(float* tension, float* SoC){
  if(bm.begin())
    Serial.println(bm.isConnected());

  // Lecture des valeurs initiales
  *tension = bm.readVDD();
  
  // Correction de la tension en fonction du courant et init soc
  *SoC = estimerSoC(*tension);
  
  Serial.print("Initialisation SoC: ");
  Serial.print(*SoC);
  Serial.println(" %");
}

// Fonction d'interpolation linéaire pour estimer le SoC en fonction de la tension
float estimerSoC(float tension) {
  if (tension >= tension_tableau[0]) 
    return soc_tableau[0];  // 100%
  if (tension <= tension_tableau[nb_points - 1]) 
    return soc_tableau[nb_points - 1];  // 0%

  for (int i = 0; i < nb_points - 1; i++) {
    if (tension <= tension_tableau[i] && tension > tension_tableau[i + 1]) {
      float deltaV = tension_tableau[i] - tension_tableau[i + 1];
      float deltaSoC = soc_tableau[i] - soc_tableau[i + 1];
      float rapport = (tension - tension_tableau[i + 1]) / deltaV;  // Correction ici
      return soc_tableau[i + 1] + rapport * deltaSoC;  // Correction ici
    }
  }
  return 0;  // Sécurité
}
