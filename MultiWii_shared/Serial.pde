static uint8_t point;
static uint8_t s[200];
void serialize16(int16_t a) {s[point++]  = a; s[point++]  = a>>8&0xff;}
void serialize8(uint8_t a)  {s[point++]  = a;}

// ***********************************
// Interrupt driven UART transmitter for MIS_OSD
// ***********************************
static uint8_t tx_ptr;
static uint8_t tx_busy = 0;

ISR_UART {
  UDR0 = s[tx_ptr++];           // Transmit next byte
  if ( tx_ptr == point ) {      // Check if all data is transmitted
    UCSR0B &= ~(1<<UDRIE0);     // Disable transmitter UDRE interrupt
    tx_busy = 0;
  }
}

void UartSendData() {              // start of the data block transmission
  tx_ptr = 0;
  UCSR0A |= (1<<UDRE0);            // Clear UDRE interrupt flag
  UCSR0B |= (1<<UDRIE0);           // Enable transmitter UDRE interrupt
  cli();UDR0 = s[tx_ptr++];sei();  // Start transmission
  tx_busy = 1;
}

void serialCom() {
  int16_t a;
  uint8_t i;
  
  if ((!tx_busy) && SerialAvailable(0)) {
    switch (SerialRead(0)) {
    #ifdef BTSERIAL
    case 'K': //receive RC data from Bluetooth Serial adapter as a remote
      rcData[THROTTLE] = (SerialRead(0) * 4) + 1000;
      rcData[ROLL]     = (SerialRead(0) * 4) + 1000;
      rcData[PITCH]    = (SerialRead(0) * 4) + 1000;
      rcData[YAW]      = (SerialRead(0) * 4) + 1000;
      rcData[AUX1]     = (SerialRead(0) * 4) + 1000;
      break;
    #endif
    #ifdef LCD_TELEMETRY
    case 'A': // button A press
    case '1':
      if (telemetry==1) telemetry = 0; else { telemetry = 1; LCDclear(); }
      break;    
    case 'B': // button B press
    case '2':
      if (telemetry==2) telemetry = 0; else { telemetry = 2; LCDclear(); }
      break;    
    case 'C': // button C press
    case '3':
           if (telemetry==3) telemetry = 0; else { telemetry = 3; LCDclear(); 
           #ifdef LOG_VALUES
              cycleTimeMax = 0;
              cycleTimeMin = 65535;
           #endif
           }
      break;    
    case 'D': // button D press
    case '4':
      if (telemetry==4) telemetry = 0; else { telemetry = 4; LCDclear(); }
      break;
    case '5':
      if (telemetry==5) telemetry = 0; else { telemetry = 5; LCDclear(); }
      break;
    case '6':
      {    
          extern unsigned int __bss_end;
          extern unsigned int __heap_start;
          extern void *__brkval;
          int free_memory;
          if((int)__brkval == 0)
            free_memory = ((int)&free_memory) - ((int)&__bss_end);
          else
            free_memory = ((int)&free_memory) - ((int)__brkval);
          strcpy_P(line1,pmsg11); //" Free ---- "   uint8_t free_memory
          line1[6] = '0' + free_memory / 1000 - (free_memory/10000) * 10;
          line1[7] = '0' + free_memory / 100  - (free_memory/1000)  * 10;
          line1[8] = '0' + free_memory / 10   - (free_memory/100)   * 10;
          line1[9] = '0' + free_memory        - (free_memory/10)    * 10;
          LCDprintChar(line1);
          break;
      }
    case 'a': // button A release
    case 'b': // button B release
    case 'c': // button C release
    case 'd': // button D release
      break;      
    #endif
    case 'M': // Multiwii @ arduino to GUI all data
      point=0;
      serialize8('M');
      serialize8(VERSION);  // MultiWii Firmware version
      for(i=0;i<3;i++) serialize16(accSmooth[i]);
      for(i=0;i<3;i++) serialize16(gyroData[i]);
      for(i=0;i<3;i++) serialize16(magADC[i]);
      serialize16(EstAlt/10);
      serialize16(heading); // compass
      for(i=0;i<4;i++) serialize16(servo[i]);
      for(i=0;i<8;i++) serialize16(motor[i]);
      for(i=0;i<8;i++) serialize16(rcData[i]);
      serialize8(nunchuk|ACC<<1|BARO<<2|MAG<<3|GPSPRESENT<<4);
      serialize8(accMode|baroMode<<1|magMode<<2|(GPSModeHome|GPSModeHold)<<3);
      #ifdef LOG_VALUES
        serialize16(cycleTimeMax);
        cycleTimeMax = 0;
      #else
        serialize16(cycleTime);
      #endif
      for(i=0;i<2;i++) serialize16(angle[i]);
      serialize8(MULTITYPE);
      for(i=0;i<5;i++) {serialize8(P8[i]);serialize8(I8[i]);serialize8(D8[i]);}
      serialize8(P8[PIDLEVEL]);
      serialize8(I8[PIDLEVEL]);
      serialize8(P8[PIDMAG]);
      serialize8(rcRate8);
      serialize8(rcExpo8);
      serialize8(rollPitchRate);
      serialize8(yawRate);
      serialize8(dynThrPID);
      for(i=0;i<CHECKBOXITEMS;i++) {serialize8(activate1[i]);serialize8(activate2[i]);}
      serialize16(GPS_distanceToHome);
      serialize16(GPS_directionToHome);
      serialize8(GPS_numSat);
      serialize8(GPS_fix);
      serialize8(GPS_update);
      #if defined(POWERMETER)
        intPowerMeterSum = (pMeter[PMOTOR_SUM]/PLEVELDIV);
        intPowerTrigger1 = powerTrigger1 * PLEVELSCALE; 
        serialize16(intPowerMeterSum);
        serialize16(intPowerTrigger1);
      #else
        serialize16(0);serialize16(0);
      #endif
      serialize8(vbat);
      serialize16(BaroAlt/10);        // 4 variables are here for general monitoring purpose
      serialize16(i2c_errors_count);  // debug2
      serialize16(annex650_overrun_count);// debug3
      serialize16(armed);             // debug4
      serialize8('M');
      UartSendData();
      break;
    case 'O':  // arduino to OSD data - contribution from MIS
      serialize8('O');
      for(i=0;i<3;i++) serialize16(accSmooth[i]);
      for(i=0;i<3;i++) serialize16(gyroData[i]);
      serialize16(EstAlt*10.0f);
      serialize16(heading); // compass - 16 bytes
      for(i=0;i<2;i++) serialize16(angle[i]); //20
      for(i=0;i<6;i++) serialize16(motor[i]); //32
      for(i=0;i<6;i++) {serialize16(rcData[i]);} //44
      serialize8(nunchuk|ACC<<1|BARO<<2|MAG<<3);
      serialize8(accMode|baroMode<<1|magMode<<2);
      serialize8(vbat);     // Vbatt 47
      serialize8(VERSION);  // MultiWii Firmware version
      serialize8('O'); //49
      break;
    case 'W': //GUI write params to eeprom @ arduino
      while (SerialAvailable(0)<(25+2*CHECKBOXITEMS)) {delay(1);}//sss
      for(i=0;i<5;i++) {P8[i]= SerialRead(0); I8[i]= SerialRead(0); D8[i]= SerialRead(0);} //15
      P8[PIDLEVEL] = SerialRead(0); I8[PIDLEVEL] = SerialRead(0); //17
      P8[PIDMAG] = SerialRead(0); //18
      rcRate8 = SerialRead(0); rcExpo8 = SerialRead(0); //20
      rollPitchRate = SerialRead(0); yawRate = SerialRead(0); //22
      dynThrPID = SerialRead(0); //23
      for(i=0;i<CHECKBOXITEMS;i++) {activate1[i] = SerialRead(0);activate2[i] = SerialRead(0);}
     #if defined(POWERMETER)
      powerTrigger1 = (SerialRead(0) + 256* SerialRead(0) ) / PLEVELSCALE; // we rely on writeParams() to compute corresponding pAlarm value
     #else
      SerialRead(0);SerialRead(0); // so we unload the two bytes
     #endif
      writeParams();
      break;
    case 'S': //GUI to arduino ACC calibration request
      calibratingA=400;
      break;
    case 'E': //GUI to arduino MAG calibration request
      calibratingM=1;
      break;
    }
  }
}

#define SERIAL_RX_BUFFER_SIZE 64

#if defined(PROMINI)
uint8_t serialBufferRX[SERIAL_RX_BUFFER_SIZE][1];
volatile uint8_t serialHeadRX[1],serialTailRX[1];
#endif
#if defined(MEGA)
uint8_t serialBufferRX[SERIAL_RX_BUFFER_SIZE][4];
volatile uint8_t serialHeadRX[4],serialTailRX[4];
#endif

void SerialOpen(uint8_t port, uint32_t baud) {
  uint8_t h = ((F_CPU  / 4 / baud -1) / 2) >> 8;
  uint8_t l = ((F_CPU  / 4 / baud -1) / 2);
  switch (port) {
    case 0: UCSR0A  = (1<<U2X0); UBRR0H = h; UBRR0L = l; UCSR0B |= (1<<RXEN0)|(1<<TXEN0)|(1<<RXCIE0); break;
    #if defined(MEGA)
    case 1: UCSR1A  = (1<<U2X1); UBRR1H = h; UBRR1L = l; UCSR1B |= (1<<RXEN1)|(1<<TXEN0)|(1<<RXCIE1); break;
    case 2: UCSR2A  = (1<<U2X2); UBRR2H = h; UBRR2L = l; UCSR2B |= (1<<RXEN2)|(1<<TXEN0)|(1<<RXCIE2); break;
    case 3: UCSR3A  = (1<<U2X3); UBRR3H = h; UBRR3L = l; UCSR3B |= (1<<RXEN3)|(1<<TXEN0)|(1<<RXCIE3); break;
    #endif
  }
}

void SerialEnd(uint8_t port) {
  switch (port) {
    case 0: UCSR0B &= ~((1<<RXEN0)|(1<<TXEN0)|(1<<RXCIE0)|(1<<UDRIE0)); break;
    #if defined(MEGA)
    case 1: UCSR1B &= ~((1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)|(1<<UDRIE1)); break;
    case 2: UCSR2B &= ~((1<<RXEN2)|(1<<TXEN2)|(1<<RXCIE2)|(1<<UDRIE2)); break;
    case 3: UCSR3B &= ~((1<<RXEN3)|(1<<TXEN3)|(1<<RXCIE3)|(1<<UDRIE3)); break;
    #endif
  }
}

#if defined(PROMINI)
SIGNAL(USART_RX_vect){
  uint8_t i = (serialHeadRX[0] + 1) % SERIAL_RX_BUFFER_SIZE;
  if (i != serialTailRX[0]) {serialBufferRX[serialHeadRX[0]][0] = UDR0; serialHeadRX[0] = i;}
}
#endif
#if defined(MEGA)
SIGNAL(USART0_RX_vect){
  uint8_t i = (serialHeadRX[0] + 1) % SERIAL_RX_BUFFER_SIZE;
  if (i != serialTailRX[0]) {serialBufferRX[serialHeadRX[0]][0] = UDR0; serialHeadRX[0] = i;}
}
SIGNAL(USART1_RX_vect){
  uint8_t i = (serialHeadRX[1] + 1) % SERIAL_RX_BUFFER_SIZE;
  if (i != serialTailRX[1]) {serialBufferRX[serialHeadRX[1]][1] = UDR1; serialHeadRX[1] = i;}
}
SIGNAL(USART2_RX_vect){
  uint8_t i = (serialHeadRX[2] + 1) % SERIAL_RX_BUFFER_SIZE;
  if (i != serialTailRX[2]) {serialBufferRX[serialHeadRX[2]][2] = UDR2; serialHeadRX[2] = i;}
}
SIGNAL(USART3_RX_vect){
  uint8_t i = (serialHeadRX[3] + 1) % SERIAL_RX_BUFFER_SIZE;
  if (i != serialTailRX[3]) {serialBufferRX[serialHeadRX[3]][3] = UDR3; serialHeadRX[3] = i;}
}
#endif

uint8_t SerialRead(uint8_t port) {
    uint8_t c = serialBufferRX[serialTailRX[port]][port];
    if ((serialHeadRX[port] != serialTailRX[port])) serialTailRX[port] = (serialTailRX[port] + 1) % SERIAL_RX_BUFFER_SIZE;
    return c;
}

uint8_t SerialAvailable(uint8_t port) {
  return (SERIAL_RX_BUFFER_SIZE + serialHeadRX[port] - serialTailRX[port]) % SERIAL_RX_BUFFER_SIZE;
}

void SerialWrite(uint8_t port,uint8_t c){
  switch (port) {
    case 0: while (!(UCSR0A & (1 << UDRIE0))) ; UDR0 = c; break;
    #if defined(MEGA)
    case 1: while (!(UCSR1A & (1 << UDRIE1))) ; UDR1 = c; break;
    case 2: while (!(UCSR2A & (1 << UDRIE2))) ; UDR2 = c; break;
    case 3: while (!(UCSR3A & (1 << UDRIE3))) ; UDR3 = c; break;
    #endif
  }
}

