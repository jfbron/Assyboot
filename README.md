# Assyboot
New bootloader for all ATMega328 Variants with EEPRom support, Smart Write and user entry for Flash/EEprom operations 

This Bootloader is completely written an Assembler, using Microchip Studio.
The size is 256 Words, (512 Bytes) leaving 31,5 KByte (31232 Bytes) for the User Application.
Is Fully backward compatible with OPTIBOOT, so can simply replace this Bootloader,
But to take full advantage some changes in the (arduino) board.txt file must be made.
New features in this Bootloader:
- Can Read and Write both Flash and EEprom
- Uses a Smart Write,meaning it compares the data send with the data already in Flas/EEprom,
  and skips the write when identical, preserving Flash and EEprom, The total no of Writes is Limited.
  This also speeds-up programming, especcially whan only minor changes are made in a program.
- All paramaters (ID Butes, Fuses and Lock Byte are read from the actual chip, so the same bootloader
  installed on a AT328, 328P or 328PB will always report the actual value, not a fixed value in the Code.
- The Bootloader also has a User Entry. This allowes the user read and Write in both Flash and EEprom
  This is a unique feature, normally the User cannot Write to Flash from a user program,
  but this Bootloader support writing and reaing pages of Flash and EEprom.
- A demo for Writing and Reading from an (Arduino) program is included.
- The Bootloader will set the LOCK bits as needed on first rud, to avoid it from beiing overwritten.
  Do not use the default value for the lock bite (0x0f) that will diaable the support for calling
  the functions for Flash/EEprom functions, leave it unprogrammed (0xFF)
- The Bootloader is also fast. I included 2 versions, one at a 115K2 speed, compatible with existing
  Bootloaders, and one at 1000K (1 MBaud) tested with both CH340XX and FTDI chips, tha Baudrate is in most cases
  the bottleneck for fast programming.    
       
