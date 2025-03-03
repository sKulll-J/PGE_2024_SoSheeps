#include "BMS.h"

// BMS instanciation
OneWire oneWire(ONE_WIRE_BUS);
DS2438 bm(&oneWire);

float tension_tableau[nb_points] = {4.20, 3.90, 3.70, 3.50, 3.30, 3.20};
float soc_tableau[nb_points] = {100, 80, 60, 30, 10, 0};

// Fonction d'initialisation du BMS
void BMS_init(float* tension, float* SoC) {
    if (bm.begin()) {
        #if DEBUG
        Serial.println(bm.isConnected());
        #endif
    }

    // Lecture des valeurs initiales
    float temperature = bm.readTemperature();
    *tension = corrigerTension(bm.readVDD(), temperature);
    *SoC = estimerSoC(*tension);

    #if DEBUG
    Serial.print("Initialisation SoC: ");
    Serial.print(*SoC);
    Serial.println(" %");
    #endif
}

// Fonction d'interpolation linéaire pour estimer le SoC en fonction de la tension
float estimerSoC(float tension) {
    if (tension >= tension_tableau[0]) 
        return soc_tableau[0];  // 100%
    if (tension <= tension_tableau[nb_points - 1]) 
        return soc_tableau[nb_points - 1];  // 0%

    for (int i = 0; i < nb_points - 1; i++) {
        if (tension > tension_tableau[i + 1] && tension <= tension_tableau[i]) { 
            float deltaV = tension_tableau[i] - tension_tableau[i + 1];
            float deltaSoC = soc_tableau[i] - soc_tableau[i + 1];
            float rapport = (tension - tension_tableau[i + 1]) / deltaV;
            return soc_tableau[i + 1] + rapport * deltaSoC;
        }
    }
    return 0;  // Sécurité
}

// Fonction de correction de la tension en fonction de la température
float corrigerTension(float tension, float temperature) {
    float correction = 0.0;

    if (temperature <= -10) {  // Froid extrême (-20°C à -10°C)
        correction = -0.2;  
    } else if (temperature < 0) {  // Froid modéré (-10°C à 0°C)
        correction = -0.15;  
    } else if (temperature < 10) {  // Frais (0°C à 10°C)
        correction = -0.10;  
    } else if (temperature > 45) {  // Chaleur élevée (> 45°C)
        correction = +0.03;  
    }
    
    return tension + correction;
}

// Fonction à utiliser qui retourne directement le SoC estimé
float getBatteryCharge() {
    float tension = bm.readVDD();
    float temperature = bm.readTemperature();

    // Appliquer correction de la tension selon la température
    float tension_corrigee = corrigerTension(tension, temperature);

    // Calculer SoC
    float SoC = estimerSoC(tension_corrigee);

    #if DEBUG
    Serial.print("Température: "); Serial.print(temperature); Serial.print(" °C, ");
    Serial.print("Tension : "); Serial.print(tension_corrigee); Serial.print(" V, ");
    Serial.print("SoC estimé: "); Serial.print(SoC); Serial.println(" %");
    #endif

    return SoC;
}
