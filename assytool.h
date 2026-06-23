// -------------------------------------------------------------------
// assytool.h
// 
// First definitions used, taken from avr\io.h 
// and the size of NanoBoot 512 Bytes, 4 Pages (of 128 Bytes)
// Values are for all variants of te ATMega328 processor
// including the -P and -PB versions.
// -------------------------------------------------------------------
// The ATmega328(P)(B) only supports Flash Writing at a Page Level
// Following the offical specs,
// FlashPageSize = 128 Bytes, EEPromPageSize = 4 Bytes  
//
// This routine access both Flash and EEProm by PageNumber.
// A ATmega328(P)(B) has 32 KByte of Flash, 256 Pages of 128 Bytes.
// and 1924 Byted of EEprom, 126 Pages of 4 Bytes.
// The ATmega328(P)(B) has 1024 Bytes of EEprom, 256 Pages of 4 Bytes.
//
// Flash Pages 252 .. 255 are used by the Bootloader.
// These pages are Write-protected, a Write attempt is ignored.
// The user application itselve is not protected,
// so it is possible to overwrite the user program, causing program corruption.
// It's the users responsibility to prevent this.
//
// The ATmega328(P)B) only supports writes to Flash from the Boot section.
// So you cannot write to Flash directly from the Application section.
// The trick used, is to call a routine in the Bootloader section,
// that will do the actual action, and than return to the calling application.
// This requires a Bootloader, that supports external calls.
// AssyBoot is the only Bootloader i know that supports this,
// This AssyTool provides the routines to access these routines.
// These routines support Read and Smart Write from/to Flash and EEprom.
// 
// It is essential to set the correct Lock bits.
// Most Bootloaders use 0x0F as value, this will prevent both reading
// and writing From/To the Bootloader.
// By Bloking the Read acces, you also block the possibility to call
// or Jump to the Boot Section. 
// The advise is lo leave the Lock unprogrammed, AssyBoot will set the
// Lock byte to block Write acces, but Allow Read Access.
// The Bootloader can only Block write Acces, but cannot unlock bits already set.
// So DO NOT PROGRAM THE LOCK BYTE, AssyBoot wil set the correct value (0xEF)
// (Only in case the Bootsection is not write Protected)
//
// The user must declare a byte[] Buffer to hold the data for Writing and reading
// This can be a single buffer, but is is allowed to use different buffers per call,
// The Pointer only points to the first Byte in Ram to use as a Buffer.
//
// -------------------------------------------------------------------

void Call_Bootldr(word pnr, byte* buf, word len, word cmd)
{ 
   register word  reg_pnr asm("r24") = pnr;
   register byte* reg_buf asm("r22") = buf;
   register word  reg_len asm("r20") = len;
   register word  reg_cmd asm("r18") = cmd;
   register word  reg_ptr asm("r16") = 0x3FFF;
                     
   asm volatile
  ( "in   r0,  __SREG__   \n\t"     // Save Sreg
    "push r0              \n\t"     // on stack
    "cli                  \n\t"     // No interrupts
    "tst  r25             \n\t"     // Page must 0..255    
    "brne Asm_Return      \n\t"     // Skip call if not zero
    "movw r30,  r16       \n\t"     // Call addres in Z Pointer
    "icall                \n\t"     // Actual Call
    "Asm_Return:          \n\t"     // start return sequence    
    "clr  r1              \n\t"     // r1 must always be zero
    "pop  r0              \n\t"     // get old SREG
    "out  __SREG__ , r0   \n\t"     // restore SREG (and IQR Status)
    :                               // Output Registers (Empty)          
    :                               // Input Registers
      "r"   (reg_pnr),              // Page Nr
      "r"   (reg_buf),              // Buffer Pointer
      "r"   (reg_len),              // Page Size
      "r"   (reg_cmd),              // Action Command
      "r"   (reg_ptr)               // Call Vector
    :                               // Globber List (other registers used)
      "r26", "r27",                 // X Pointer
      "r30", "r31",                 // Z pointer  
      "r0" , "memory"               // R0 Temp (Sreg_Save) and Memory Option
  );                                // End asm 
}                                   // End Call_Bootldr

// The actual routines are implemented as #define macros
// The macros will call above assembler routine with the parameters needed.
// the user calls are:
// 
// WriteFlashPage (PageNumber,Buffer)
// WriteEEPage    (PageNumber,Buffer)
// ReadFlashPage  (PageNumber,Buffer)
// ReadEEPage     (PageNumber,Buffer)
 
const word  WR_Flash     = 0;
const word  WR_EEProm    = 1;
const word  RD_Flash     = 2;
const word  RD_EEProm    = 3; 
const word  FL_PageSize  = 128;
const word  EE_PageSize  = 4;

#define WriteFlashPage( P_Nr,Buf_Ptr) Call_Bootldr(P_Nr,Buf_Ptr,FL_PageSize,WR_Flash ) 
#define WriteEEPromPage(P_Nr,Buf_Ptr) Call_Bootldr(P_Nr,Buf_Ptr,EE_PageSize,WR_EEProm) 
#define ReadFlashPage(  P_Nr,Buf_Ptr) Call_Bootldr(P_Nr,Buf_Ptr,FL_PageSize,RD_Flash ) 
#define ReadEEPromPage( P_Nr,Buf_Ptr) Call_Bootldr(P_Nr,Buf_Ptr,EE_PageSize,RD_EEProm)
 
// -------------------------------------------------------------------
// End assytool.h
// -------------------------------------------------------------------
