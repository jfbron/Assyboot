// =================================== 
// AssyBoot Demo Program
// 
// Author: J.F. Bron
// ===================================
// This program Demo program shows how to use the calls to assyboot
// for reading and Writing from/to Flash and EEprom
// results can be monitoren using a terminal program as (1 MBaud)
// Modify if out want to scange the Baudrate.
// Program repeats upon entering a space character   

#include "assytool.h"

// The assyboot bootloader has some extra features, not present in other bootloaders
//
// - Read and Write of Both EEProm and Flash Memory
// - Uses a Smart-Write algorithm, data wil only be written if different from the existing
//   This will make writing faster, but also protects the processor buid in Flash and EEprom
//   Because the number of writes to these memories is limited. Only writes when data has changed. 
// - The Read and Write routine are also available for User Programs using a small routine
//
// From a programmers view this bootloader also has some unique features:
//
// - The Bootloader reads the on-chip ID Locations and Fuses, so you will always get the actual values.
//   Most Bootloaders have these value hard coded in the program,
//   so when installed on another processor. .e..e a 328PB, you have to recompile the bootloqader. 
// - The Bootloader will also set the Lock bit when not set, to protect it from beiing overwritten.
//   So use the advised initial setting 0xff (Unprogrammed).
//   Using the default bootloader fuses 0x0f will disable the option to call the bootloaders
//   internal functions tor read/write Flash/EEprom woth a call to this bootloader
// 
// The bootloader works fast with a 1 MHz Baudrate, for fast programming,
// This has been tested wit bott a ftdi FT232R and a Ch340xxx chip.
// for compatibility the Bootloader is also compiled tu run with a 115.2K Baudrate,
// when programming you can select a version with Optiboot Bootloader.
//    
// For Optimum performance better use the 1MBaud version, but this will require a small
// change in the boards.txt file, to include the Assyboot 1MBaud in AVRDUDE
//
// This short demo program shows how to use the Flash and EEprom Read and Write functions
// Using a 128 Byte Page for Flash, and a (emulated) 4 Byte Page for EEprom
// as defined in the ATMega328(P)(B) datasheets.
//
// This program wil also give a indication of the time used to Read and Write Data
// The same data will be written several times, to demonstrate that re-Writing is mach faster.
// in case the same data is already present
// 
// However, we cannot use the build-in timer function, because these functions are interrupt driven.
// The bootloader wers and write functions will disable all interrups while running, 
// so these functions will produce invalid results. 
// 
// To avoid the build-in Timer functions to be includen, we don't use the the
// common used "void setup()" and the "void loop()" construction,
// but the "int main()" construction, that will exclude the Timer and Analog write functions.
// 
// instead this demo uses Timer 1 als a 16 bit timer, running as 2 Mhz (assuming a 16 MHz Clock)
// so dividing the no of ticks by 2 gives a time in µSec.    
// This will give a max time of +/- 32 mSec, a perfect fit for the expected max write time.   

// The R/W functions all neet a byte[] array for reading/storing Data of one (Flash), 128 Bytes. 

byte FlashBuf[128];  // Buffer

// We will Read write to one page in Flash (128 Bytes) and Eeprom (4 Bytes).
// This is compatible with the Page sizes als specified in the Datasheet.
// It will show the timing for the first write, and a second write with the sam data, and a read.
// so you can see that overwriting with the same data is faster (skipped)
// 
// Also internally Writing to Flash is done per Page, en Writing to EEprom per Byte.
// So writing 4 Bytes th EEProm takes more time than Writing 128 Bytes to Flash.
// Writing 128 Bytes to Flash can tke of to four seconds, and during that time
// all interrupts are halted, causing problems for all background functions
// as buffered I/O functions, Timers, en Analog Output/Tone functions.

word TestPage = 200; // Selected Page Number
word BootPage = 252; // First Page Bootsection
byte Selection;      // Serial input char
word Interval;       // Timing
long ReadTime;       // Total Read Time
long WriteTime;      // Total Write Time 
long EraseTime;      // Total Erase Time

// Individual functions

// Fill_Buffer fills the FlashBuf with characters 0x40 to 0xbf
// Reports Interval in µsec

void  Fill_Buffer()
{
  TCNT1 = 0;                      // Start Timing
  for (byte t = 0; t<128; t++)    // Repeat
    FlashBuf[t] = 0x40 + t;       // Write Data to Buffer
  Interval  = TCNT1 >> 1 ;        // Read Timer
  Report(0);                      // Display Data + Timing
}

// Empty_Buffer fills the FlashBuf with characters 0xFF (Unprogrammed);
// Reports Interval in µsec

void  Empty_Buffer()
{
  TCNT1 = 0;                      // Start Timing
  for (byte t = 0; t<128; t++)    // Repeat 
    FlashBuf[t] = 0xFF;           // Write empt schars
  Interval  = TCNT1 >> 1;         // Read Timer
  Report(0);                      // Display Data + Timing 
}

// Read_Flash will read the contents of the flash Page Selected into the Buffer
// Reports Interval in µsec

void  Read_Flash(word Page)
{
  TCNT1     = 0;                  // start Timer
  ReadFlashPage(Page,FlashBuf);   // Call
  Interval  = TCNT1 >> 1;         // Read Timer
  Report(Page);                       // Display Data + Timing
}

// Read_EEprom will read the contents of the flash Page Selected into the Buffer
// Reports Interval in µsec
  
void  Read_EEProm(word Page)
{
  TCNT1     = 0;                  // start Timer
  ReadEEPromPage(Page,FlashBuf);  // Call
  Interval  = TCNT1 >> 1;         // Read Timer
  Report(Page);                       // Display Data + Timing
}

// Write_Flash writes contents of the buffer to the Page selected.
// Reports Interval in µsec

void  Write_Flash(word Page)
{
  TCNT1     = 0;                  // start Timer
  WriteFlashPage(Page,FlashBuf);  // Call
  Interval  = (long) TCNT1 >> 1;  // Read Timer
  Report(Page);                       // Display Data + Timing
}

// Write_EEprom writes contents of the buffer to the Page selected.
// Reports Interval in µsec

void  Write_EEProm(word Page)
{
  TCNT1     = 0;                  // start Timer
  WriteEEPromPage(Page,FlashBuf); // Call
  Interval  = TCNT1 >> 1;         // Read Timer
  Report(Page);                       // Display Data + Timing
}

// Report shows the first 4 Bytes of the buffer and duration of the action

void Report(word Page)
{
  if (Page)
  {
    Serial.print(" Page ");
    Serial.print(Page);   
  };

  Serial.print( " Data");
  for (byte t = 0; t<4; t++)        // Init Loop
  {
    Serial.print(" 0x");            // Print " 0x" for Hex notation 
    Serial.print(FlashBuf[t], HEX); // Print the value in HEX
  };
  
  Serial.print (" Finished in ");   // Text for Tining
  Serial.print (Interval);          // Duration is µsec
  Serial.println (" µsec");         // Text " µsec" + CRLF
  Serial.flush();                   // Wait until printing is done
}

int main()
{

// initialize timer 1 for free running at 2 MHz without Interrupts.

  TIMSK1    = 0x00;           // Disable Timer1 Interrupts
  TCCR1A    = 0x00;           // Free running mode, no Output Pins
  TCCR1B    = 0x02;           // CLock Divider 8x, resulting is a 2 MHz Clock 

  asm ("sei \n\t");           // Enable Interrupts; Needed for Serial interface;
  Serial.begin(115200);      // Serial is used for displaying timing results
                              // and for selection of the test

// Main body shows the timing for Flash and EEprom
//
// Main loop:
//
// Flash Timing: 
//
// - Read Original Data in Flash Page
// - Fill Buffer with Data
// - Write Data to Flash Page
// - Re-Write same data to same Flash Page (Smart_Write Demo)
// - Empty the Buffer
// - Read the Page from Flash (To verify that the read is working)
// - Empty the Buffer
// - Write Page to Flash (effectively erase)
// - Write same buffer to same page of Flash (Smart Erase)
//
// EEProm Timing:
//
// - Do above again for EEProm Page (4 Bytes)
//
// - Loop Control
//
// - Wait until the user enters a space character
// - repeat the loop
//

  while (true)
  {
    Serial.println("Flash Demo");
    Serial.println();

    Serial.print("Read Original Flash");
    Read_Flash(TestPage);
    
    Serial.print("Fill Buffer with");
    Fill_Buffer();
    
    Serial.print("Smart Write");
    Write_Flash(TestPage);
    
    Serial.print("Smart Re-Write");
    Write_Flash(TestPage);
    
    Serial.print("Erase Buffer");
    Empty_Buffer();
    
    Serial.print("Read Flash");
    Read_Flash(TestPage);

    Serial.print("Empty Buffer");
    Empty_Buffer();
    
    Serial.print("Smart Erase Flash");
    Write_Flash(TestPage);
    
    Serial.print("Smart Re-Erase Flash");
    Write_Flash(TestPage);

    Serial.print("Erase BootSector");
    Write_Flash(BootPage);

    Serial.print("Read Bootsector");
    Read_Flash(BootPage);
    
    Serial.println();
    Serial.println("EEProm Demo");
    Serial.println();

    Serial.print("Read Original EEprom");
    Read_EEProm(TestPage);
    
    Serial.print("Fill Buffer");
    Fill_Buffer();
    
    Serial.print("Smart Write EEprom");
    Write_EEProm(TestPage);
    
    Serial.print("Smart Re-Write EEProm");
    Write_EEProm(TestPage);
    
    Serial.print("Empty Buffer");
    Empty_Buffer();
    
    Serial.print("Read EEProm");
    Read_EEProm(TestPage);

    Serial.print("Erase Buffer");
    Empty_Buffer();
    
    Serial.print("Smart Erase EEProm");
    Write_EEProm(TestPage);
    
    Serial.print("Smart Re-Erase EEProm");
    Write_EEProm(TestPage);
  
    Serial.println();

    Serial.println("Enter a Space character to repeat");
    Serial.flush(); 

    while (' ' != Serial.read());     
  };
  
}    
