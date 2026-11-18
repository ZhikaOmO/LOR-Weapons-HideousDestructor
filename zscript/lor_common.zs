// ------------------------------------------------------------
// Shared constants for the Legacy of Rust port
// ------------------------------------------------------------

//loadout refids - lowercase only, 3 characters, checked against HD's list for clashes
const LORLD_INCINERATOR="inc";
const LORLD_CALAMITY="cbl";
const LORLD_FUEL="fue";
const LORLD_PACK="lpk";
const LORLD_FUELUNIT="fuu";

//fuel economy. The original game: Fuel Can=10, Fuel Tank=50, Incinerator=1/flame, Calamity Blade=10/pulse.
//A tank is 3x the original (150): fifteen pulses, or 150 flames = the original's whole carry cap.
const LOR_TANKFUEL=150;
const LOR_CANFUEL=10;
const LOR_PULSEFUEL=10;
const LOR_MAXPULSES=5;
const LOR_PACKFUEL=600;     //flamethrower pack capacity
const LOR_BLASTFUEL=6;      //Incinerator scatter blast cost
const LOR_BLASTFLAMES=10;   //flames per full blast
const LOR_BALLISTAFUEL=30;  //Calamity Blade ballista base shot cost
const LOR_BALLISTA_EXTRA=15; //extra fuel per charge level
const LOR_BALLISTA_STEP=30;  //tics of altfire per charge level
const LOR_BALLISTA_MAXLVL=3;

//weaponstatus layout shared by both fuel weapons
enum LoRFuelStatus{
	LORF_FLAGS=0,
	LORF_FUEL=1,    //-1 = no tank loaded
	LORF_HEAT=2,
	LORF_PULSES=3,  //Calamity Blade: pulses stored so far
	LORF_CHARGE=4,  //Calamity Blade: tics spent charging (wave smoke / ballista charge)

	LORFF_JUSTUNLOAD=1,
	LORFF_WIDE=2,   //Incinerator: scatter-blast nozzle
	LORFF_LINKED=4, //hose linked to a worn flamethrower pack
	LORFF_BALLISTA=8, //Calamity Blade: ballista mode
};
