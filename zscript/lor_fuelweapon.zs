// ------------------------------------------------------------
// Common base for the two fuel-fed weapons:
// one swappable, individually-tracked fuel tank, HD-style reloads.
// ------------------------------------------------------------
class LoRFuelWeapon:HDWeapon abstract{
	default{
		hdweapon.ammo1 "LoRFuelTank",1;
	}
	override bool AddSpareWeapon(actor newowner){return AddSpareWeaponRegular(newowner);}
	override hdweapon GetSpareWeapon(actor newowner,bool reverse,bool doselect){return GetSpareWeaponRegular(newowner,reverse,doselect);}
	//iron sights - placeholder art copied from the HD pistol (Incinerator: graphics/loifsite.png + loibsite.png; Calamity Blade: locfsite.png + locbsite.png)
	override void DrawSightPicture(
		HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl,
		bool sightbob,vector2 bob,double fov,bool scopeview,actor hpc
	){
		//each weapon has its own sight images
		string spre=(hdw is "LoRCalamityBlade")?"loc":"loi";
		int cx,cy,cw,ch;
		[cx,cy,cw,ch]=screen.GetClipRect();
		vector2 bobb=bob*1.3;
		sb.SetClipRect(
			-8+bob.x,-9+bob.y,16,15,
			sb.DI_SCREEN_CENTER
		);
		sb.drawimage(
			spre.."fsite",(0,0)+bobb,sb.DI_SCREEN_CENTER|sb.DI_ITEM_TOP,
			scale:(0.6,0.6)
		);
		sb.SetClipRect(cx,cy,cw,ch);
		sb.drawimage(
			spre.."bsite",(0,0)+bob,sb.DI_SCREEN_CENTER|sb.DI_ITEM_TOP,
			alpha:0.9,
			scale:(0.6,0.6)
		);
	}
	override void DropOneAmmo(int amt){
		if(owner){
			amt=clamp(amt,1,10);
			owner.A_DropInventory("LoRFuelTank",1);
		}
	}
	override void failedpickupunload(){
		failedpickupunloadmag(LORF_FUEL,"LoRFuelTank");
	}
	override void initializewepstats(bool idfa){
		weaponstatus[LORF_FUEL]=LOR_TANKFUEL;
	}
	override void tick(){
		super.tick();
		drainheat(LORF_HEAT,12);
		//hose goes slack if the pack is gone
		if(
			(weaponstatus[LORF_FLAGS]&LORFF_LINKED)
			&&(!owner||!LoRFuelPackWorn.Find(owner))
		)weaponstatus[LORF_FLAGS]&=~LORFF_LINKED;
	}
	bool PackLinked(){
		return (weaponstatus[LORF_FLAGS]&LORFF_LINKED)&&owner&&LoRFuelPackWorn.Find(owner);
	}
	//everything this weapon could burn right now: linked pack + own tank
	clearscope int FuelAvailable(){
		int ful=max(0,weaponstatus[LORF_FUEL]);
		if((weaponstatus[LORF_FLAGS]&LORFF_LINKED)&&owner)ful+=LoRFuelPackWorn.Available(owner);
		return ful;
	}
	//burn fuel: linked pack first, then the loaded tank. Returns what was actually drawn.
	int DrawFuel(int amt){
		int got=0;
		if(PackLinked())got=LoRFuelPackWorn.Draw(owner,amt);
		int rest=amt-got;
		if(rest>0&&weaponstatus[LORF_FUEL]>0){
			int tk=min(rest,weaponstatus[LORF_FUEL]);
			weaponstatus[LORF_FUEL]-=tk;
			got+=tk;
		}
		return got;
	}
	string PackHelpText(){
		return StringTable.Localize(
			(weaponstatus[LORF_FLAGS]&LORFF_LINKED)?"$LORPACKWH_UNLINK":"$LORPACKWH_LINK"
		);
	}

	//reserve tanks and the loaded fuel gauge
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		if(sb.hudlevel==1){
			sb.drawimage("FTNKA0",(-52,-5),sb.DI_SCREEN_CENTER_BOTTOM,scale:(0.45,0.45));
			sb.drawnum(hpl.countinv("LoRFuelTank"),-46,-8,sb.DI_SCREEN_CENTER_BOTTOM);
		}
		let pk=LoRFuelPackWorn.Find(hpl);
		if(pk&&(hdw.weaponstatus[LORF_FLAGS]&LORFF_LINKED)){
			sb.drawstring(
				sb.psmallfont,"PACK "..pk.fuel,
				(-16,-25),sb.DI_TEXT_ALIGN_RIGHT|sb.DI_SCREEN_CENTER_BOTTOM,
				Font.CR_GREEN
			);
		}
		int fuel=hdw.weaponstatus[LORF_FUEL];
		if(fuel>0)sb.drawwepnum(fuel,LOR_TANKFUEL);
		else if(!fuel)sb.drawstring(
			sb.mamountfont,"00000",
			(-16,-9),sb.DI_TEXT_ALIGN_RIGHT|sb.DI_TRANSLATABLE|sb.DI_SCREEN_CENTER_BOTTOM,
			Font.CR_DARKGRAY
		);
	}

	states{
	user3:
		#### A 0 A_MagManager("LoRFuelTank");
		goto ready;

	unload:
		#### A 0{
			//with the hose linked, Unload disconnects it
			if(invoker.weaponstatus[LORF_FLAGS]&LORFF_LINKED)return resolvestate("linkhose");
			invoker.weaponstatus[LORF_FLAGS]|=LORFF_JUSTUNLOAD;
			if(invoker.weaponstatus[LORF_FUEL]>=0)
				return resolvestate("unmag");
			return resolvestate("nope");
		}goto magout;
	unmag:
		#### A 2 offset(0,33){
			A_SetCrosshair(21);
			A_MuzzleClimb(frandom(-1.2,-2.4),frandom(1.2,2.4));
		}
		#### A 3 offset(0,35) A_StartSound("weapons/bfgopen",8);
		#### A 6 offset(0,40) A_StartSound("weapons/bfgclick2",8,CHANF_OVERLAP);
		#### A 0{
			int fuel=invoker.weaponstatus[LORF_FUEL];
			A_MuzzleClimb(frandom(-1.2,-2.4),frandom(1.2,2.4));
			if(
				fuel<0
				||(!PressingUnload()&&!PressingReload())
			)return resolvestate("dropmag");
			return resolvestate("pocketmag");
		}

	dropmag:
		---- A 0{
			int fuel=invoker.weaponstatus[LORF_FUEL];
			invoker.weaponstatus[LORF_FUEL]=-1;
			if(fuel>=0)HDMagAmmo.SpawnMag(self,"LoRFuelTank",fuel);
		}goto magout;

	pocketmag:
		---- A 0{
			int fuel=invoker.weaponstatus[LORF_FUEL];
			invoker.weaponstatus[LORF_FUEL]=-1;
			if(fuel>=0)HDMagAmmo.GiveMag(self,"LoRFuelTank",fuel);
		}
		#### A 8 offset(0,43) A_StartSound("weapons/pocket",9);
		#### A 8 offset(0,42) A_StartSound("weapons/pocket",9,CHANF_OVERLAP);
		goto magout;

	magout:
		---- A 0 A_JumpIf(invoker.weaponstatus[LORF_FLAGS]&LORFF_JUSTUNLOAD,"reload3");
		goto loadmag;

	reload:
		#### A 0{
			invoker.weaponstatus[LORF_FLAGS]&=~LORFF_JUSTUNLOAD;
			if(
				invoker.weaponstatus[LORF_FUEL]<LOR_TANKFUEL
				&&LoRFuelTank.BestSpare(self)>invoker.weaponstatus[LORF_FUEL]
			)setweaponstate("unmag");
			else if(
				LoRFuelPackWorn.Find(self)
				&&!(invoker.weaponstatus[LORF_FLAGS]&LORFF_LINKED)
			)setweaponstate("linkhose");
		}goto nope;

	//connect/disconnect the pack hose (toggle)
	linkhose:
		#### A 1 offset(0,34) A_SetCrosshair(21);
		#### A 2 offset(6,38) A_StartSound("weapons/pocket",8);
		#### A 3 offset(12,44) A_MuzzleClimb(0.3,0.4);
		#### A 6 offset(16,48) A_StartSound("weapons/bfgclick",8);
		#### A 4 offset(12,44) A_StartSound("weapons/pocket",9);
		#### A 2 offset(6,38){
			A_WeaponBusy();
			invoker.weaponstatus[LORF_FLAGS]^=LORFF_LINKED;
		}
		#### A 2 offset(2,34) A_StartSound("weapons/bfgclick2",8);
		#### A 1 offset(0,33);
		goto nope;

	loadmag:
		#### A 2 offset(0,43){
			A_StartSound("weapons/pocket",9);
			if(health>39)A_SetTics(0);
		}
		#### AA 2 offset(0,42);
		#### A 2 offset(0,44) A_StartSound("weapons/pocket",9);
		#### A 4 offset(0,43);
		#### A 6 offset(0,42);
		#### A 8 offset(0,38) A_StartSound("weapons/bfgopen",8);
		#### A 4 offset(0,37){if(health>39)A_SetTics(0);}
		#### A 4 offset(0,36) A_StartSound("weapons/bfgclick2",8);
		#### A 0{
			let tnk=LoRFuelTank(findinventory("LoRFuelTank"));
			if(tnk)invoker.weaponstatus[LORF_FUEL]=tnk.TakeBestMag();
		}goto reload3;

	reload3:
		#### A 6 offset(0,40) A_StartSound("weapons/bfgclick",8);
		#### A 2 offset(0,36);
		#### A 4 offset(0,33);
		goto nope;
	}
}
