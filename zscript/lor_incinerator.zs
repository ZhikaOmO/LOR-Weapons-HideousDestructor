// ------------------------------------------------------------
// Incinerator
// Original: fuel flamethrower, 1 fuel per flame, ~11.7 flames/s,
// flames fly at 40 u/tic for 16 tics and leave burning ground.
// HD additions: tracked fuel tank, stream/spray nozzle, heat,
// real ignition of victims, self-burn risk, window breaking.
// ------------------------------------------------------------
class LoRIncinerator:LoRFuelWeapon{
	default{
		//$Category "Weapons/Hideous Destructor"
		//$Title "Incinerator"
		//$Sprite "INCPA0"

		weapon.selectionorder 71;
		weapon.slotnumber 6;
		weapon.slotpriority 2;
		weapon.bobrangex 0.25;
		weapon.bobrangey 0.9;
		scale 0.6;
		inventory.pickupmessage "$PICKUP_LORINCINERATOR";
		obituary "$OB_LORINCINERATOR";
		hdweapon.barrelsize 26,2,3;
		hdweapon.refid LORLD_INCINERATOR;
		tag "$TAG_LORINCINERATOR";
		hdweapon.loadoutcodes "
			\cuspray - 0/1, start with the scatter blast nozzle";
	}
	override double gunmass(){
		return 13+(weaponstatus[LORF_FUEL]>=0?2:0);
	}
	override double weaponbulk(){
		int fuel=weaponstatus[LORF_FUEL];
		return 230+(fuel>=0?(8+fuel*0.1):0);
	}
	override string,double getpickupsprite(){return "INCPA0",1.;}
	override void loadoutconfigure(string input){
		int spray=getloadoutvar(input,"spray",1);
		if(!spray)weaponstatus[0]&=~LORFF_WIDE;
		else if(spray>0)weaponstatus[0]|=LORFF_WIDE;
	}
	override string gethelptext(){
		LocalizeHelp();
		return
		LWPHELP_FIRESHOOT
		..LWPHELP_FIREMODE
		..StringTable.Localize("$LORINCWH_SWITCH")
		..(weaponstatus[LORF_FLAGS]&LORFF_WIDE?StringTable.Localize("$LORINCWH_STREAM"):StringTable.Localize("$LORINCWH_BLAST"))
		..StringTable.Localize("$LORINCWH_NOZZLE")
		..LWPHELP_RELOADRELOAD
		..PackHelpText()
		..LWPHELP_UNLOADUNLOAD
		..LWPHELP_MAGMANAGER
		;
	}
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		super.DrawHUDStuff(sb,hdw,hpl);
		bool wide=(hdw.weaponstatus[LORF_FLAGS]&LORFF_WIDE)!=0;
		sb.drawstring(
			sb.psmallfont,wide?"BLAST":"STREAM",
			(-16,-17),sb.DI_TEXT_ALIGN_RIGHT|sb.DI_SCREEN_CENTER_BOTTOM,
			Font.CR_ORANGE
		);
	}

	//spawn a single flame. spread in degrees, spd in units/tic.
	action void A_LoRSpitFlame(double spreadang,double spreadpitch,double spd){
		double aa=angle;
		double pp=pitch;
		let hdp=hdplayerpawn(self);
		if(hdp){
			aa=hdp.gunangle;
			pp=hdp.gunpitch;
		}
		aa+=frandom(-spreadang,spreadang)+frandom(-spreadang,spreadang)*0.5;
		pp+=frandom(-spreadpitch,spreadpitch)+frandom(-spreadpitch,spreadpitch)*0.5;
		//only about one flame in three carries a dynamic light: the rest look the same but cost far less
		let fl=LoRFlame(spawn(random(0,2)?"LoRFlame":"LoRFlameLit",pos+gunpos((8,0,-3)),ALLOW_REPLACE));
		if(!fl)return;
		fl.angle=aa;
		fl.pitch=pp;
		fl.target=self;
		fl.master=self;
		fl.speed=spd;
		fl.vel=vel*0.5+(cos(pp)*cos(aa),cos(pp)*sin(aa),-sin(pp))*spd;
	}
	//stream nozzle: one flame per puff, rapid fire
	action void A_LoRBurner(){
		if(invoker.DrawFuel(1)<1){
			setweaponstate("dry");
			return;
		}
		invoker.weaponstatus[LORF_HEAT]+=2;
		A_StartSound("lor/inc/fire",CHAN_WEAPON,CHANF_OVERLAP);
		A_LoRSpitFlame(1.1,0.8,40.);
		A_MuzzleClimb(frandom(-0.2,0.2),frandom(-0.1,0.25));
		A_ZoomRecoil(0.998);
		if(!random(0,5))A_AlertMonsters();
		if(invoker.weaponstatus[LORF_HEAT]>40&&!random(0,2)){
			spawn("HDSmoke",pos+gunpos((10,0,-2)),ALLOW_REPLACE);
		}
	}
	//scatter nozzle: a shotgun-like blast of flames in one pull
	action void A_LoRBlast(){
		int cost=min(LOR_BLASTFUEL,invoker.FuelAvailable());
		if(cost<1){
			setweaponstate("dry");
			return;
		}
		invoker.DrawFuel(cost);
		int n=(cost>=LOR_BLASTFUEL)?LOR_BLASTFLAMES:max(2,cost*LOR_BLASTFLAMES/LOR_BLASTFUEL);
		invoker.weaponstatus[LORF_HEAT]+=12;
		A_StartSound("lor/inc/fire1",CHAN_WEAPON,CHANF_OVERLAP,1.,ATTN_NORM,0.7);
		A_StartSound("lor/inc/fire2",CHAN_AUTO,CHANF_OVERLAP,1.,ATTN_NORM,0.55);
		A_StartSound("lor/inc/burn",CHAN_AUTO,CHANF_OVERLAP,0.9);
		for(int i=0;i<n;i++){
			//triangular spread: tight centre, ragged edge, like a choke-less shotgun
			A_LoRSpitFlame(7.,4.5,frandom(26.,38.));
		}
		A_MuzzleClimb(
			0,0,
			-frandom(0.5,1.),-frandom(2.,3.4),
			-frandom(0.2,0.5),-frandom(1.,2.)
		);
		A_ZoomRecoil(0.94);
		A_ChangeVelocity(-1.,0,0.3,CVF_RELATIVE);
		A_AlertMonsters();
		hdmobai.frighten(self,256);
		for(int j=0;j<3;j++)spawn("HDSmoke",pos+gunpos((12,frandom(-3,3),frandom(-3,1))),ALLOW_REPLACE);
	}

	states{
	ready:
		INCG A 1 A_WeaponReady(WRF_ALL&~WRF_ALLOWUSER1);
		goto readyend;
	select0:
		INCG A 0;
		goto select0big;
	deselect0:
		INCG A 0;
		goto deselect0big;

	fire:
		INCG A 1 offset(0,34);
	hold:
		INCG A 0{
			if(invoker.FuelAvailable()<1)return resolvestate("dry");
			if(invoker.weaponstatus[LORF_FLAGS]&LORFF_WIDE)return resolvestate("blast");
			return resolvestate("shoot");
		}
	shoot:
		INCF A 1 bright offset(1,34){
			A_Light2();
			A_LoRBurner();
		}
		INCF B 1 bright offset(0,34) A_Light1();
		INCG A 1 offset(0,33) A_Light0();
		INCG A 0 A_Refire();
		goto nope;
	//shotgun-style blast: one pull, one burst, then a pump before the next
	blast:
		INCF A 1 bright offset(2,36){
			A_Light2();
			A_LoRBlast();
		}
		INCF B 1 bright offset(4,40) A_Light1();
		INCG A 2 offset(3,44) A_Light0();
		INCG A 3 offset(2,48);
		INCG A 3 offset(1,44) A_StartSound("weapons/bfgclick2",8,CHANF_OVERLAP);
		INCG A 4 offset(0,40) A_StartSound("weapons/bfgclick",8,CHANF_OVERLAP);
		INCG A 3 offset(0,36);
		INCG A 2 offset(0,33);
		INCG A 0 A_ReFire("fire");
		goto nope;
	dry:
		INCG A 4 offset(0,35) A_StartSound("weapons/plasmas",8);
		goto nope;

	firemode:
		INCG A 1 offset(1,33) A_WeaponBusy();
		INCG A 2 offset(2,35);
		INCG A 1 offset(1,38) A_StartSound("weapons/bfgclick",8);
		INCG A 3 offset(0,40);
		INCG A 2 offset(0,38){
			invoker.weaponstatus[LORF_FLAGS]^=LORFF_WIDE;
			A_SetHelpText();
		}
		INCG A 1 offset(0,35);
		INCG A 1 offset(0,33);
		goto nope;

	spawn:
		INCP A -1;
		stop;
	}
}

// ------------------------------------------------------------
// The flame itself
// ------------------------------------------------------------
class LoRFlame:HDActor{
	int burnleft;
	default{
		+missile +noblockmap +dropoff +nogravity +forcexybillboard
		+bright +notelestomp +hittracer
		radius 13;height 8;speed 40;
		renderstyle "translucent";alpha 0.66;
		damagefunction(random(4,20));
		damagetype "hot";
		obituary "$OB_LORINCINERATOR";
	}
	void A_FlameFly(){
		vel.z+=0.06;
		if(waterlevel>1){
			spawn("HDSmoke",pos,ALLOW_REPLACE);
			destroy();
		}
	}
	//direct hit: real HD fire, not just damage
	void A_FlameHit(){
		//ground fire lasts 2.5x as long as the original (about 106 tics of burn).
		//when the map is already full of flames, new ones burn shorter so the sim stays cheap.
		int load=LoRHandler.FlameLoad();
		burnleft=load>150?4:(load>80?7:11);
		A_StartSound(random(0,1)?"lor/inc/hit1":"lor/inc/hit2",CHAN_BODY);
		if(tracer&&!tracer.bnodamage){
			HDF.Give(tracer,"Heat",random(30,60));
			A_Immolate(tracer,target,random(20,50));
		}
		if(blockingline)doordestroyer.CheckDirtyWindowBreak(blockingline,0.02,pos);
	}
	//lingering fire on the ground/wall; hurts everyone nearby, shooter included
	void A_FlameBurn(){
		A_HDBlast(
			blastradius:64,blastdamage:4,fullblastradius:24,blastdamagetype:"hot",
			immolateradius:56,immolateamount:random(8,20),immolatechance:30
		);
		if(!random(0,7))spawn("HDSmoke",pos+(frandom(-8,8),frandom(-8,8),frandom(0,16)),ALLOW_REPLACE);
	}
	states{
	spawn:
		INFL A 1 bright;
		INFL A 2 bright;
		INFL B 2 bright{if(!random(0,2))A_StartSound("lor/inc/burn",CHAN_BODY,CHANF_OVERLAP,0.7);}
		INFL C 2 bright A_FlameFly();
		INFL D 2 bright A_FlameFly();
		INFL E 2 bright A_FlameFly();
		INFL F 2 bright A_FlameFly();
		INFL G 2 bright A_FlameFly();
		INFL H 2 bright A_FlameFly();
		stop;
	death:
		INFL A 0 A_FlameHit();
		INFL I 2 bright A_FlameBurn();
		INFL J 2 bright;
	burnloop:
		INFL K 2 bright;
		INFL L 2 bright A_FlameBurn();
		INFL M 2 bright;
		INFL L 2 bright{
			if(--burnleft>0)return resolvestate("burnloop");
			return resolvestate(null);
		}
		INFL N 2 bright A_StartSound("lor/inc/hit3",CHAN_BODY,CHANF_OVERLAP,0.6);
		INFL O 2 bright A_FlameBurn();
		INFL N 2 bright;
		INFL O 2 bright;
		INFL P 2 bright;
		INFL O 2 bright;
		INFL P 2 bright;
		stop;
	}
}

//the lit variant: same flame with a dynamic light (see gldefs.lor)
class LoRFlameLit:LoRFlame{}
