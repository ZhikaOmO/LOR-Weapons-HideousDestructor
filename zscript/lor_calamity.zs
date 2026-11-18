// ------------------------------------------------------------
// Calamity Blade (Heatwave Generator)
// Original: hold fire to stack up to 5 pulses (10 fuel each, 20 tics apiece);
// release to throw 3/6/9/12/15 ripping heat waves in a 5-degree-spaced fan.
// Waves fly perfectly flat at 20 u/tic and rip through everything.
// HD additions: tracked tank, heavy-weapon handling, recoil/kickback
// scaling with charge, heat, real ignition, window breaking.
// ------------------------------------------------------------
class LoRCalamityBlade:LoRFuelWeapon{
	default{
		//$Category "Weapons/Hideous Destructor"
		//$Title "Calamity Blade"
		//$Sprite "CBLPA0"

		+hdweapon.hinderlegs
		weapon.selectionorder 92;
		weapon.slotnumber 7;
		weapon.slotpriority 2;
		weapon.bobrangex 0.3;
		weapon.bobrangey 1.0;
		weapon.bobspeed 1.8;
		scale 0.7;
		inventory.pickupmessage "$PICKUP_LORCALAMITY";
		obituary "$OB_LORCALAMITY";
		hdweapon.barrelsize 30,3,6;
		hdweapon.refid LORLD_CALAMITY;
		tag "$TAG_LORCALAMITY";
	}
	override double gunmass(){
		return 16+(weaponstatus[LORF_FUEL]>=0?2:0);
	}
	override double weaponbulk(){
		int fuel=weaponstatus[LORF_FUEL];
		return 250+(fuel>=0?(8+fuel*0.1):0);
	}
	override string,double getpickupsprite(){return "CBLPA0",1.;}
	override string gethelptext(){
		LocalizeHelp();
		bool bal=(weaponstatus[LORF_FLAGS]&LORFF_BALLISTA)!=0;
		return
		(bal?LWPHELP_ALTFIRE..StringTable.Localize("$LORCBLWH_BALCHARGE"):"")
		..LWPHELP_FIRE..StringTable.Localize(bal?"$LORCBLWH_BALFIRE":"$LORCBLWH_FIRE")
		..LWPHELP_FIREMODE..StringTable.Localize("$LORCBLWH_SWITCH")
		..StringTable.Localize(bal?"$LORCBLWH_WAVES":"$LORCBLWH_BALLISTA")
		..StringTable.Localize("$LORCBLWH_MODE")
		..LWPHELP_RELOADRELOAD
		..PackHelpText()
		..LWPHELP_UNLOADUNLOAD
		..LWPHELP_MAGMANAGER
		;
	}
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		super.DrawHUDStuff(sb,hdw,hpl);
		bool bal=(hdw.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA)!=0;
		sb.drawstring(
			sb.psmallfont,bal?"BALLISTA":"WAVES",
			(-16,-17),sb.DI_TEXT_ALIGN_RIGHT|sb.DI_SCREEN_CENTER_BOTTOM,
			Font.CR_ORANGE
		);
		if(bal){
			int c=hdw.weaponstatus[LORF_CHARGE];
			int lvl=c/LOR_BALLISTA_STEP;
			for(int i=0;i<LOR_BALLISTA_MAXLVL;i++){
				if(i<lvl)sb.drawrect(-46+i*6,-19,4,4);
				else if(i==lvl&&c>0){
					int h=1+((c%LOR_BALLISTA_STEP)*3)/LOR_BALLISTA_STEP;
					sb.drawrect(-46+i*6,-15-h,4,h);
				}else sb.drawrect(-46+i*6,-16,4,1);
			}
			return;
		}
		int stored=hdw.weaponstatus[LORF_PULSES];
		let lw=LoRFuelWeapon(hdw);
		int possible=lw?lw.FuelAvailable()/LOR_PULSEFUEL:0;
		for(int i=0;i<LOR_MAXPULSES;i++){
			if(i<stored)sb.drawrect(-46+i*6,-19,4,4);
			else if(i<stored+possible)sb.drawrect(-46+i*6,-16,4,1);
		}
	}

	//one pulse: burn fuel, add to the stack, play the glow strip
	action void A_LoRChargePulse(){
		invoker.DrawFuel(LOR_PULSEFUEL);
		invoker.weaponstatus[LORF_PULSES]++;
		invoker.weaponstatus[LORF_HEAT]+=10;
		A_StartSound("lor/cbl/charge",CHAN_WEAPON);
		A_AlertMonsters(256);
		switch(invoker.weaponstatus[LORF_PULSES]){
		case 1:A_Overlay(PSP_FLASH,"flash1");break;
		case 2:A_Overlay(PSP_FLASH,"flash2");break;
		case 3:A_Overlay(PSP_FLASH,"flash3");break;
		case 4:A_Overlay(PSP_FLASH,"flash4");break;
		default:A_Overlay(PSP_FLASH,"flash5");break;
		}
	}
	//per-tic strain while charging
	action void A_LoRChargeTick(){
		A_WeaponReady(WRF_NOFIRE|WRF_DISABLESWITCH);
		int p=invoker.weaponstatus[LORF_PULSES];
		A_WeaponOffset(frandom(-0.3,0.3)*p,32+frandom(0,0.4)*p,WOF_INTERPOLATE);
		A_MuzzleClimb(frandom(-0.05,0.05)*p,frandom(-0.05,0.05)*p);
		//smoke builds from a wisp to the full plume over the first five pulses, then stays there
		invoker.weaponstatus[LORF_CHARGE]++;
		double f=min(1.,invoker.weaponstatus[LORF_CHARGE]/(LOR_MAXPULSES*20.));
		if(frandom(0,1)<0.03+0.14*f){
			let sm=spawn("HDSmoke",pos+gunpos((12,0,-6)),ALLOW_REPLACE);
			if(sm){
				sm.scale*=0.3+0.7*f;
				sm.alpha*=0.5+0.5*f;
			}
		}
	}
	//one high-power bolt, dead straight along the gun's aim
	//altfire held: build charge, up to what the fuel can pay for
	action void A_LoRBallistaCharge(){
		A_WeaponReady(WRF_NOFIRE|WRF_DISABLESWITCH);
		int c=invoker.weaponstatus[LORF_CHARGE];
		int maxlvl=clamp((invoker.FuelAvailable()-LOR_BALLISTAFUEL)/LOR_BALLISTA_EXTRA,0,LOR_BALLISTA_MAXLVL);
		if(c<maxlvl*LOR_BALLISTA_STEP){
			c++;
			if(!(c%LOR_BALLISTA_STEP)){
				int l=c/LOR_BALLISTA_STEP;
				A_StartSound("lor/cbl/charge",CHAN_WEAPON,CHANF_OVERLAP,0.7,ATTN_NORM,0.7+0.15*l);
				A_AlertMonsters(256);
				invoker.weaponstatus[LORF_HEAT]+=10;
			}
		}
		invoker.weaponstatus[LORF_CHARGE]=c;
		int lv=c/LOR_BALLISTA_STEP;
		A_WeaponOffset(frandom(-0.25,0.25)*lv,32+frandom(0,0.3)*lv,WOF_INTERPOLATE);
		A_MuzzleClimb(frandom(-0.04,0.04)*lv,frandom(-0.04,0.04)*lv);
		if(lv&&frandom(0,1)<0.05*lv){
			let sm=spawn("HDSmoke",pos+gunpos((12,0,-6)),ALLOW_REPLACE);
			if(sm)sm.scale*=0.3+0.15*lv;
		}
	}
	action void A_LoRBallista(){
		int lvl=clamp(invoker.weaponstatus[LORF_CHARGE]/LOR_BALLISTA_STEP,0,LOR_BALLISTA_MAXLVL);
		int avail=invoker.FuelAvailable();
		while(lvl>0&&LOR_BALLISTAFUEL+LOR_BALLISTA_EXTRA*lvl>avail)lvl--;
		int cost=LOR_BALLISTAFUEL+LOR_BALLISTA_EXTRA*lvl;
		if(invoker.DrawFuel(cost)<cost){
			setweaponstate("dry");
			return;
		}
		invoker.weaponstatus[LORF_CHARGE]=0;
		//Doom Eternal-style charge tiers: more damage, speed, blast and recoil, bigger bolt
		double dm=1.+0.6*lvl;
		double sm=1.+0.25*lvl;
		double rm=1.+0.3*lvl;
		double aa=angle;
		double pp=pitch;
		let hdp=hdplayerpawn(self);
		if(hdp){
			aa=hdp.gunangle;
			pp=hdp.gunpitch;
		}
		vector3 dir=(cos(pp)*cos(aa),cos(pp)*sin(aa),-sin(pp));
		let bl=LoRBolt(spawn("LoRBolt",pos+gunpos((10,0,-2)),ALLOW_REPLACE));
		if(bl){
			bl.target=self;
			bl.master=self;
			bl.angle=aa;
			bl.pitch=pp;
			bl.lvl=lvl;
			bl.dmult=dm;
			bl.rmult=rm;
			bl.speed*=sm;
			bl.scale*=1.+0.25*lvl;
			bl.vel=dir*bl.speed;
		}
		A_StartSound("lor/cbl/shoot",CHAN_WEAPON,CHANF_OVERLAP,1.,ATTN_NORM,0.6-0.06*lvl);
		A_StartSound("lor/cbl/charge",CHAN_AUTO,CHANF_OVERLAP,0.8,ATTN_NORM,0.7);
		A_AlertMonsters();
		hdmobai.frighten(self,512);
		invoker.weaponstatus[LORF_HEAT]+=60+20*lvl;
		double rc=1.+0.4*lvl;
		A_ZoomRecoil(0.88-0.03*lvl);
		A_MuzzleClimb(
			0,0,
			-frandom(0.6,1.2)*rc,-frandom(5.,7.)*rc,
			-frandom(0.3,0.7)*rc,-frandom(2.,3.5)*rc
		);
		A_ChangeVelocity(-2.*rc,0,0.4,CVF_RELATIVE);
		A_GunFlash();
		for(int j=0;j<4;j++)spawn("HDSmoke",pos+gunpos((12,frandom(-2,2),frandom(-3,1))),ALLOW_REPLACE);
	}
	//release the fan
	action void A_LoRHeatwaves(){
		int p=clamp(invoker.weaponstatus[LORF_PULSES],1,LOR_MAXPULSES);
		int n=p*3;
		double baseang=angle;
		double pp=pitch;
		let hdp=hdplayerpawn(self);
		if(hdp){
			baseang=hdp.gunangle;
			pp=hdp.gunpitch;
		}
		double zz=pos.z+max(16.,gunheight()-12.);
		vector3 origin=(
			pos.x+cos(pp)*cos(baseang)*14.,
			pos.y+cos(pp)*sin(baseang)*14.,
			zz-sin(pp)*14.
		);
		for(int i=0;i<n;i++){
			double a=baseang+(i-(n-1)*0.5)*5.;
			//only the centre wave carries a dynamic light
			let wv=LoRHeatwave(spawn(i==n/2?"LoRHeatwaveLit":"LoRHeatwave",origin,ALLOW_REPLACE));
			if(!wv)continue;
			wv.target=self;
			wv.master=self;
			wv.angle=a;
			wv.pitch=pp;
			wv.vel=(cos(pp)*cos(a)*20.,cos(pp)*sin(a)*20.,-sin(pp)*20.);
		}
		A_StartSound("lor/cbl/shoot",CHAN_WEAPON,CHANF_OVERLAP);
		A_AlertMonsters();
		hdmobai.frighten(self,512);
		invoker.weaponstatus[LORF_HEAT]+=20*p;
		A_ZoomRecoil(1.-0.03*p);
		A_MuzzleClimb(
			0,0,
			-frandom(0.4,0.8)*p,-frandom(0.8,1.6)*p,
			-frandom(0.2,0.5)*p,-frandom(0.4,0.9)*p
		);
		A_ChangeVelocity(-0.5*p,0,0.15*p,CVF_RELATIVE);
		A_GunFlash();
	}

	states{
	ready:
		CBLG A 0 A_JumpIf(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA,"readyb");
		CBLG A 1{
			invoker.weaponstatus[LORF_PULSES]=0;
			invoker.weaponstatus[LORF_CHARGE]=0;
			A_WeaponReady(WRF_ALL&~WRF_ALLOWUSER1);
		}
		goto readyend;
	readyb:
		BLSG A 1{
			invoker.weaponstatus[LORF_CHARGE]=0;
			A_WeaponReady(WRF_ALL&~WRF_ALLOWUSER1);
		}
		goto readyend;
	//Ballista: hold altfire to charge, press fire to release
	altfire:
		CBLG A 0 A_JumpIf(!(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA),"nope");
		BLSG A 0{
			if(invoker.FuelAvailable()<LOR_BALLISTAFUEL)return resolvestate("dry");
			return resolvestate(null);
		}
	ballistacharge:
		BLSG A 1{
			A_LoRBallistaCharge();
			if(PressingFire())return resolvestate("ballista");
			if(!PressingAltfire()){
				invoker.weaponstatus[LORF_CHARGE]=0;
				return resolvestate("nope");
			}
			return resolvestate(null);
		}
		wait;
	select0:
		CBLG A 0 A_JumpIf(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA,"select0b");
		CBLG A 0;
		goto select0bfg;
	select0b:
		BLSG A 0;
		goto select0bfg;
	deselect0:
		CBLG A 0 A_JumpIf(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA,"deselect0b");
		CBLG A 0;
		goto deselect0bfg;
	deselect0b:
		BLSG A 0;
		goto deselect0bfg;

	//swap between heat waves and ballista
	firemode:
		#### A 1 offset(1,34) A_WeaponBusy();
		#### A 2 offset(2,38);
		#### A 3 offset(0,42) A_StartSound("weapons/bfgclick",8);
		#### A 2 offset(0,40){
			invoker.weaponstatus[LORF_FLAGS]^=LORFF_BALLISTA;
			A_SetHelpText();
		}
		#### A 0 A_JumpIf(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA,"firemodeb");
		CBLG A 2 offset(0,36) A_StartSound("weapons/bfgclick2",8);
		CBLG A 1 offset(0,33);
		goto nope;
	firemodeb:
		BLSG A 2 offset(0,36) A_StartSound("weapons/bfgclick2",8);
		BLSG A 1 offset(0,33);
		goto nope;

	fire:
		CBLG A 0{
			invoker.weaponstatus[LORF_PULSES]=0;
			if(invoker.weaponstatus[LORF_FLAGS]&LORFF_BALLISTA){
				if(invoker.FuelAvailable()<LOR_BALLISTAFUEL)return resolvestate("dry");
				return resolvestate("ballista");
			}
			if(invoker.FuelAvailable()<LOR_PULSEFUEL)return resolvestate("dry");
			invoker.weaponstatus[LORF_CHARGE]=0;
			return resolvestate("charge");
		}
	charge:
		CBLG A 0 A_LoRChargePulse();
		CBLG AAAAAAAAAAAAAAAAAAAA 1 A_LoRChargeTick();
		CBLG A 0{
			if(!PressingFire())return resolvestate("release");
			if(
				invoker.weaponstatus[LORF_PULSES]<LOR_MAXPULSES
				&&invoker.FuelAvailable()>=LOR_PULSEFUEL
			)return resolvestate("charge");
			return resolvestate("chargehold");
		}
	//fully charged: hold as long as you like
	chargehold:
		CBLG A 1{
			A_LoRChargeTick();
			if(!PressingFire())return resolvestate("release");
			return resolvestate(null);
		}
		wait;
	ballista:
		BLSG A 0;
		BLSF A 2 bright offset(0,36) A_LoRBallista();
		BLSF B 2 bright offset(0,42);
		BLSG D 6 offset(0,50);
		BLSG C 6 offset(0,46) A_StartSound("weapons/bfgclick2",8,CHANF_OVERLAP);
		BLSG B 8 offset(0,42);
		BLSG A 6 offset(0,36) A_StartSound("weapons/bfgclick",8,CHANF_OVERLAP);
		BLSG A 8 offset(0,33);
		goto nope;
	release:
		CBLF A 3 bright offset(0,36) A_LoRHeatwaves();
		CBLF B 5 bright offset(0,40);
		CBLG D 4 offset(0,46);
		CBLG C 4 offset(0,40);
		CBLG B 4 offset(0,35);
		CBLG A 2 offset(0,33){
			invoker.weaponstatus[LORF_PULSES]=0;
		}
		goto nope;
	dry:
		CBLG A 4 offset(0,35) A_StartSound("weapons/plasmas",8);
		goto nope;

	flash:
		TNT1 A 3 A_Light2();
		TNT1 A 5 A_Light1();
		TNT1 A 0 A_Light0();
		stop;
	flash1:
		CBLC A 6 bright;
		CBLC B 5 bright;
		CBLC C 5 bright;
		CBLC D 5 bright;
		stop;
	flash2:
		CBLC E 6 bright;
		CBLC F 5 bright;
		CBLC G 5 bright;
		CBLC H 5 bright;
		stop;
	flash3:
		CBLC I 6 bright;
		CBLC J 5 bright;
		CBLC K 5 bright;
		CBLC L 5 bright;
		stop;
	flash4:
		CBLC M 6 bright;
		CBLC N 5 bright;
		CBLC O 5 bright;
		CBLC P 5 bright;
		stop;
	flash5:
		CBLC Q 6 bright;
		CBLC R 5 bright;
		CBLC S 5 bright;
		CBLC T 5 bright;
		loop;

	spawn:
		CBLP A -1;
		stop;
	}
}

// ------------------------------------------------------------
// The heat wave: flat, rips through everything until it hits a wall
// ------------------------------------------------------------
class LoRHeatwave:HDActor{
	int lifetime;
	default{
		+missile +ripper +noblockmap +dropoff +nogravity +forcexybillboard
		+bright +notelestomp
		radius 16;height 8;speed 20;
		renderstyle "translucent";alpha 0.66;
		damagefunction(random(8,22));
		damagetype "hot";
		deathsound "lor/cbl/explode";
		obituary "$OB_LORCALAMITY";
	}
	//the lifetime counter runs once per 3-tic animation step instead of every tic
	void A_WaveTick(){
		if(bmissile&&++lifetime>100)ExplodeMissile();
	}
	override int DoSpecialDamage(actor victim,int damage,name damagetype){
		if(victim&&!victim.bnodamage){
			HDF.Give(victim,"Heat",random(15,45));
			if(!random(0,3))A_Immolate(victim,target,random(20,60));
		}
		return damage;
	}
	void A_WaveBurst(){
		if(blockingline)doordestroyer.CheckDirtyWindowBreak(blockingline,0.03,pos);
	}
	states{
	spawn:
		CBLB ABC 3 bright A_WaveTick();
		loop;
	death:
		CBLB D 3 bright A_WaveBurst();
		CBLB EFGHI 3 bright;
		stop;
	}
}

//the wave with a light, used for the middle wave of each fan
class LoRHeatwaveLit:LoRHeatwave{}

// ------------------------------------------------------------
// Ballista bolt: the heat wave, stretched and squashed into a needle:
// one fast, perfectly straight, hard-hitting shot
// ------------------------------------------------------------
class LoRBolt:HDActor{
	int lifetime;
	int lvl;
	double dmult,rmult;
	override void postbeginplay(){
		super.postbeginplay();
		if(dmult<=0)dmult=1.;
		if(rmult<=0)rmult=1.;
	}
	default{
		+missile +ripper +noblockmap +dropoff +nogravity +forcexybillboard
		+bright +notelestomp +hittracer
		//thin as a needle so it can't snag on corners when you lean around them
		radius 2;height 2;speed 180;
		renderstyle "translucent";alpha 0.85;xscale 2.4;yscale 0.35;
		damagefunction(random(225,345));
		damagetype "hot";
		deathsound "lor/cbl/explode";
		obituary "$OB_LORCALAMITY";
	}
	override void tick(){
		super.tick();
		if(!bmissile)return;
		if(++lifetime>200)ExplodeMissile();
		else if(lifetime>2&&!random(0,9)){
			//only the odd faint wisp, so the bolt itself stays visible
			let sm=spawn("HDSmoke",pos,ALLOW_REPLACE);
			if(sm){
				sm.scale*=0.2;
				sm.alpha*=0.4;
			}
		}
	}
	//it passes through whatever it hits: every victim catches fire
	override int DoSpecialDamage(actor victim,int damage,name damagetype){
		if(victim&&!victim.bnodamage){
			HDF.Give(victim,"Heat",random(60,120));
			A_Immolate(victim,target,random(40,90));
		}
		return int(damage*dmult);
	}
	void A_BoltBurst(){
		A_HDBlast(
			blastradius:int(128*rmult),blastdamage:int(90*dmult),fullblastradius:int(40*rmult),blastdamagetype:"hot",
			immolateradius:int(96*rmult),immolateamount:random(30,70),immolatechance:70
		);
		if(blockingline)doordestroyer.CheckDirtyWindowBreak(blockingline,0.5,pos);
	}
	states{
	spawn:
		CBLB ABC 2 bright;
		loop;
	death:
		BALX A 3 bright A_BoltBurst();
		BALX BCDEF 3 bright;
		stop;
	}
}
