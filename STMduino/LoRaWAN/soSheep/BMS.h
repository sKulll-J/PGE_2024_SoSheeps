#pragma once
#include <DS2438.h>

#define ONE_WIRE_BUS 2

const uint8_t nb_points = 6;

void BMS_init(float* tension, float* SoC);
float estimerSoC(float tension);