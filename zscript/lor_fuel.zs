// ------------------------------------------------------------
// Fuel Tank
// A tracked magazine, just like batteries: every tank remembers
// its own fill level. The map's "Fuel Can" (10) and "Fuel Tank" (50)
// are the same item at different fill levels.
// ------------------------------------------------------------
class LoRFuelTank:HDMagAmmo{
	default{
		//$Category "Ammo/Hideous Destructor/"
		//$Title "Fuel Tank"
		//$Sprite "FTNKA0"

		hdmagammo.maxperunit LOR_TANKFUEL;
		hdmagammo.roundtype "LoRFuelUnit";
		hdmagammo.roundbulk 0.1;
		hdmagammo.magbulk 8;
		hdmagammo.mustshowinmagmanager true;
		tag "$TAG_LORFUEL";
		hdpickup.refid LORLD_FUEL;
		hdpickup.bulk 23;
		inventory.pickupmessage "$PICKUP_LORFUELTANK";
		inventory.icon "FTNKA0";
		scale 0.5;
	}
	override string PickupMessage(){
		if(mags.size()&&mags[0]<=LOR_CANFUEL)return Stringtable.Localize("$PICKUP_LORFUELCAN");
		return Stringtable.Localize("$PICKUP_LORFUELTANK");
	}
	//take the fullest tank rather than just the first/last
	int TakeBestMag(){
		SyncAmount();
		if(amount<1)return -1;
		int bi=0;
		for(int i=1;i<mags.size();i++){
			if(mags[i]>mags[bi])bi=i;
		}
		int val=mags[bi];
		mags.delete(bi);
		amount=mags.size();
		return val;
	}
	//the fullest spare tank in someone's pockets
	static int BestSpare(actor who){
		let tnk=LoRFuelTank(who.findinventory("LoRFuelTank"));
		if(!tnk)return 0;
		tnk.SyncAmount();
		int best=0;
		for(int i=0;i<tnk.mags.size();i++)best=max(best,tnk.mags[i]);
		return best;
	}
	override string,string,name,double getmagsprite(int thismagamt){
		return (thismagamt>LOR_CANFUEL?"FTNKA0":"FTNKB0"),"FUELA0","LoRFuelUnit",1.2;
	}
	override void GetItemsThatUseThis(){
		itemsthatusethis.push("LoRIncinerator");
		itemsthatusethis.push("LoRCalamityBlade");
	}
	states(actor){
	spawn:
		//NOT nodelay: SpawnMag() fills mags[] only after spawn() returns,
		//so the first tic is the earliest it is safe to look at them.
		FTNK A 1{
			if(mags.size()&&mags[0]<=LOR_CANFUEL)return resolvestate("spawncan");
			return resolvestate(null);
		}
		FTNK A -1;
		stop;
	spawncan:
		FTNK B -1;
		stop;
	spawnempty:
		FTNK B -1;
		stop;
	}
}

//Loose fuel: the "round" that fuel cans/tanks (and the pack) are magazines of.
//Pull it out of a can with the mag manager; push it back in the same way.
class LoRFuelUnit:HDRoundAmmo{
	default{
		//$Category "Ammo/Hideous Destructor/"
		//$Title "Loose Fuel"
		//$Sprite "FUELA0"
		+inventory.ignoreskill
		+hdpickup.multipickup
		scale 0.5;
		tag "$TAG_LORFUELUNIT";
		hdpickup.refid LORLD_FUELUNIT;
		hdpickup.bulk 0.1;
		inventory.pickupmessage "$PICKUP_LORFUELUNIT";
		inventory.icon "FUELA0";
	}
	//Loose fuel never spawns by itself (no replacement rule creates it);
	//it exists only when mappers place it, loadouts ("fuu"), or you extract/pour it.
	override void GetItemsThatUseThis(){
		itemsthatusethis.push("LoRFuelTank");
		itemsthatusethis.push("LoRFuelPack");
		itemsthatusethis.push("LoRIncinerator");
		itemsthatusethis.push("LoRCalamityBlade");
	}
	states{
	spawn:
		FUEL A -1;
		stop;
	}
}

//stands in for a Fuel Can pickup: a tank holding just 10 units
class LoRFuelCanSpawn:IdleDummy{
	override void postbeginplay(){
		super.postbeginplay();
		let tnk=LoRFuelTank(spawn("LoRFuelTank",pos,ALLOW_REPLACE));
		if(tnk){
			tnk.mags.clear();
			tnk.amount=0;
			tnk.AddAMag(LOR_CANFUEL);
			tnk.angle=angle;
		}
		destroy();
	}
}
