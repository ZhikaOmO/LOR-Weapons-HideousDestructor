// ------------------------------------------------------------
// Flamethrower Pack
// A wearable backpack-layer fuel reservoir. Wear it with Use (or hold Use
// while picking it up); then press Reload on an Incinerator / Calamity Blade
// to link its hose. Linked weapons draw from the pack first, then from their
// own tank. Other flamethrower mods can be fed from it too: see lorcompat.lor.
//
// Structure follows the supplied HDStinker gas-tank code (pickup magazine
// -> Use -> worn item holding the fuel).
// ------------------------------------------------------------
class LoRFuelPack:HDMagAmmo{
	default{
		//$Category "Items/Hideous Destructor"
		//$Title "Flamethrower Pack"
		//$Sprite "FTPKA0"
		+inventory.invbar
		+hdpickup.cheatnogive
		+hdpickup.notinpockets
		-hdpickup.fitsinbackpack
		+inventory.isarmor
		inventory.amount 1;
		hdmagammo.maxperunit LOR_PACKFUEL;
		hdmagammo.roundtype "LoRFuelUnit";
		hdmagammo.roundbulk 0.1;
		hdmagammo.magbulk 60;
		hdmagammo.mustshowinmagmanager true;
		tag "$TAG_LORPACK";
		inventory.icon "FTPKA0";
		inventory.pickupmessage "$PICKUP_LORPACK";
	}
	int cooldown;
	override bool isused(){return true;}
	override string,string,name,double getmagsprite(int thismagamt){
		return "FTPKA0","FUELA0","LoRFuelUnit",0.6;
	}
	override int getsbarnum(int flags){
		int ms=mags.size()-1;
		if(ms<0)return -1000000;
		return mags[ms]%1000;
	}
	//a pack may hold more than a tank ever would; no per-unit cap beyond LOR_PACKFUEL
	override void AddAMag(int addamt){
		if(addamt<0)addamt=LOR_PACKFUEL;
		mags.push(addamt);
		amount=mags.size();
	}
	override void MaxCheat(){
		syncamount();
		for(int i=0;i<amount;i++)mags[i]=LOR_PACKFUEL;
	}
	//open the mag manager on spare packs: works however full or empty they are
	action void A_OpenPackManager(){
		A_SetInventory("MagManager",1);
		let mmm=MagManager(findinventory("MagManager"));
		if(!mmm)return;
		mmm.thismag=hdmagammo(findinventory("LoRFuelPack"));
		mmm.thismagtype="LoRFuelPack";
		UseInventory(mmm);
	}
	action void A_WearPack(){
		invoker.syncamount();
		int ful=invoker.mags[invoker.mags.size()-1];
		//holding Use, or already wearing a pack: open the manager instead of wearing it
		if((!!player&&(player.cmd.buttons&BT_USE))||LoRFuelPackWorn.Find(self)){
			A_OpenPackManager();
			return;
		}

		invoker.wornlayer=STRIP_BACKPACK;
		bool intervening=!HDPlayerPawn.CheckStrip(self,invoker,false);
		invoker.wornlayer=0;

		if(intervening){
			//is it only another backpack-layer item in the way?
			invoker.wornlayer=STRIP_BACKPACK+1;
			bool notbackpack=!HDPlayerPawn.CheckStrip(self,invoker,false);
			invoker.wornlayer=0;
			if(
				notbackpack
				||invoker.cooldown>0
			){
				HDPlayerPawn.CheckStrip(self,self);
			}else invoker.cooldown=10;
			return;
		}

		LoRFuelPack.WearEffect(self,100);
		A_GiveInventory("LoRFuelPackWorn");
		let worn=LoRFuelPackWorn(FindInventory("LoRFuelPackWorn"));
		worn.fuel=ful;
		invoker.amount--;
		invoker.mags.pop();
		LoRFuelPack.WearHelpText(self,ful);
		invoker.syncamount();
	}
	override void doeffect(){
		if(cooldown>0)cooldown--;
		if(!amount)destroy();
	}
	override void syncamount(){
		if(amount<1){destroy();return;}
		super.syncamount();
		for(int i=0;i<amount;i++)mags[i]=min(mags[i],LOR_PACKFUEL);
	}
	override void beginplay(){
		super.beginplay();
		cooldown=0;
		if(!mags.size())mags.push(LOR_PACKFUEL);
	}
	override void consolidate(){}
	override double getbulk(){
		//no SyncAmount() here: newer HD forbids it inside GetBulk, so just read what is there
		double blk=0;
		int n=min(amount,mags.size());
		for(int i=0;i<n;i++)blk+=60+(min(mags[i],LOR_PACKFUEL)*0.1);
		return blk;
	}
	override double getbulkonemag(int which){
		return magbulk;
	}
	static void WearHelpText(actor wearer,int fuel){
		if(!HDWeapon.CheckDoHelpText(wearer))return;
		wearer.A_Log(
			Stringtable.Localize("$ARMOUR_PUTON")
			..Stringtable.Localize("$TAG_LORPACK")
			..Stringtable.Localize("$HD_SENTENCEBREAK")
			..fuel.."/"..LOR_PACKFUEL
		,true);
	}
	override bool BeforePockets(actor other){
		//put it on right away when picked up while holding Use
		if(
			other.player
			&&other.player.cmd.buttons&BT_USE
			&&!other.findinventory("LoRFuelPackWorn")
		){
			wornlayer=STRIP_BACKPACK;
			bool intervening=!HDPlayerPawn.CheckStrip(other,self,false);
			wornlayer=0;
			if(intervening)return false;

			LoRFuelPack.WearEffect(other,110);
			let worn=LoRFuelPackWorn(other.GiveInventoryType("LoRFuelPackWorn"));
			int ful=mags[mags.size()-1];
			worn.fuel=ful;
			LoRFuelPack.WearHelpText(other,ful);
			destroy();
			return true;
		}
		return false;
	}
	override void actualpickup(actor other,bool silent){
		cooldown=0;
		if(!other)return;
		int fuelamt=mags[mags.size()-1];
		let existing=LoRFuelPack(other.findinventory("LoRFuelPack"));
		if(existing){
			//too heavy to haul more than three spare packs
			if((existing.mags.size()+1)*hdmath.getencumbrancemult()>3.)return;
		}
		if(!trypickup(other))return;
		existing=LoRFuelPack(other.findinventory("LoRFuelPack"));
		existing.syncamount();
		existing.mags.insert(0,fuelamt);
		existing.mags.pop();
		other.A_StartSound(pickupsound,CHAN_AUTO);
		HDPickup.LogPickupMessage(other,pickupmessage());
	}
	static void WearEffect(actor owner,int delay=25){
		owner.A_StartSound("weapons/pocket",CHAN_BODY);
		owner.vel.z+=1.;
		let onr=HDPlayerPawn(owner);
		if(onr){
			onr.stunned+=45;
			onr.striptime=delay;
			onr.AddBlackout(256,96,128);
		}else owner.A_SetBlend("00 00 00",1,6,"00 00 00");
	}
	states{
	spawn:
		FTNK A -1;
		stop;
	use:
		TNT1 A 0 A_WearPack();
		fail;
	}
}

//the worn half: holds the actual fuel
class LoRFuelPackWorn:HDDamageHandler{
	int fuel;
	default{
		+inventory.isarmor
		tag "$TAG_LORPACK";
		inventory.maxamount 1;
		+inventory.invbar //HDDamageHandler turns this off; the worn pack needs to be usable from the inventory bar
		inventory.icon "FTPKA0";
		HDDamageHandler.priority 0;
		HDPickup.wornlayer STRIP_BACKPACK;
	}
	int xcool;
	override void DoEffect(){
		super.DoEffect();
		if(xcool>0)xcool--;
	}
	override int getsbarnum(int flags){return fuel;}
	//Use: pour fuel from your tanks into the pack.
	//Hold the Use key while pressing it: pour the pack out into your tanks.
	action void A_PackTransfer(){
		let pk=LoRFuelPackWorn(invoker);
		if(!pk||pk.xcool>0)return;
		pk.xcool=10;
		bool drain=player&&(player.cmd.buttons&BT_USE);
		let tnk=LoRFuelTank(findinventory("LoRFuelTank"));
		if(tnk)tnk.SyncAmount();
		int bi=-1;
		int amt=0;
		if(!drain){
			int room=LOR_PACKFUEL-pk.fuel;
			if(room<1){A_Log("The pack is full.",true);return;}
			//loose fuel first
			int loose=countinv("LoRFuelUnit");
			if(loose>0){
				amt=min(room,loose);
				A_TakeInventory("LoRFuelUnit",amt,TIF_NOTAKEINFINITE);
				pk.fuel+=amt;
				A_StartSound("weapons/pocket",CHAN_BODY);
				A_Log("Pack: "..pk.fuel.."/"..LOR_PACKFUEL.."  (refilled from loose fuel)",true);
				return;
			}
			//then spare packs in your pockets
			let sp=LoRFuelPack(findinventory("LoRFuelPack"));
			if(sp){
				sp.SyncAmount();
				int si=-1;
				for(int i=0;i<sp.mags.size();i++){
					if(sp.mags[i]>0&&(si<0||sp.mags[i]<sp.mags[si]))si=i;
				}
				if(si>=0){
					amt=min(room,sp.mags[si]);
					sp.mags[si]-=amt;
					pk.fuel+=amt;
					A_StartSound("weapons/pocket",CHAN_BODY);
					A_Log("Pack: "..pk.fuel.."/"..LOR_PACKFUEL.."  (refilled from a spare pack)",true);
					return;
				}
			}
			if(!tnk){A_Log("No fuel to draw from.",true);return;}
			//then the emptiest non-empty tank first
			for(int i=0;i<tnk.mags.size();i++){
				if(tnk.mags[i]>0&&(bi<0||tnk.mags[i]<tnk.mags[bi]))bi=i;
			}
			if(bi<0){A_Log("Your tanks are empty.",true);return;}
			amt=min(room,tnk.mags[bi]);
			tnk.mags[bi]-=amt;
			pk.fuel+=amt;
		}else{
			if(pk.fuel<1){A_Log("The pack is empty.",true);return;}
			//top off the fullest tank that still has room
			if(tnk){
				for(int i=0;i<tnk.mags.size();i++){
					if(tnk.mags[i]<LOR_TANKFUEL&&(bi<0||tnk.mags[i]>tnk.mags[bi]))bi=i;
				}
			}
			if(bi<0){
				//no can with room: try a spare pack
				let sp=LoRFuelPack(findinventory("LoRFuelPack"));
				if(sp){
					sp.SyncAmount();
					int si=-1;
					for(int i=0;i<sp.mags.size();i++){
						if(sp.mags[i]<LOR_PACKFUEL&&(si<0||sp.mags[i]>sp.mags[si]))si=i;
					}
					if(si>=0){
						amt=min(LOR_PACKFUEL-sp.mags[si],pk.fuel);
						sp.mags[si]+=amt;
						pk.fuel-=amt;
						A_StartSound("weapons/pocket",CHAN_BODY);
						A_Log("Pack: "..pk.fuel.."/"..LOR_PACKFUEL.."  (drained into a spare pack)",true);
						return;
					}
				}
				//decant into loose fuel instead
				amt=min(pk.fuel,HDPickup.MaxGive(self,"LoRFuelUnit",0.1));
				if(amt<1){A_Log("No room for more fuel.",true);return;}
				HDF.Give(self,"LoRFuelUnit",amt);
				pk.fuel-=amt;
				A_StartSound("weapons/pocket",CHAN_BODY);
				A_Log("Pack: "..pk.fuel.."/"..LOR_PACKFUEL.."  (drained to loose fuel)",true);
				return;
			}
			amt=min(LOR_TANKFUEL-tnk.mags[bi],pk.fuel);
			tnk.mags[bi]+=amt;
			pk.fuel-=amt;
		}
		A_StartSound("weapons/pocket",CHAN_BODY);
		A_StartSound("lor/inc/burn",CHAN_AUTO,CHANF_OVERLAP,0.3);
		A_Log("Pack: "..pk.fuel.."/"..LOR_PACKFUEL..(drain?"  (drained into a tank)":"  (refilled from a tank)"),true);
	}
	override void beginplay(){
		super.beginplay();
		fuel=LOR_PACKFUEL;
	}
	override double RestrictSpeed(double speedcap){
		return min(speedcap,4.);
	}
	override double getbulk(){
		return 60+(fuel*0.1);
	}

	//---- API for weapons (ours and other mods') ----
	clearscope static LoRFuelPackWorn Find(actor who){
		if(!who)return null;
		return LoRFuelPackWorn(who.findinventory("LoRFuelPackWorn"));
	}
	clearscope static int Available(actor who){
		let pk=Find(who);
		return pk?pk.fuel:0;
	}
	//take up to amt; returns what was actually taken
	static int Draw(actor who,int amt){
		let pk=Find(who);
		if(!pk||amt<1)return 0;
		int got=min(amt,pk.fuel);
		pk.fuel-=got;
		return got;
	}
	static int Add(actor who,int amt){
		let pk=Find(who);
		if(!pk||amt<1)return 0;
		int got=min(amt,LOR_PACKFUEL-pk.fuel);
		pk.fuel+=got;
		return got;
	}

	override void DrawHudStuff(
		hdstatusbar sb,
		hdplayerpawn hpl,
		int hdflags,
		int gzflags
	){
		vector2 coords=
			(hdflags&HDSB_AUTOMAP)?(4,64):
			(85,-4)
		;
		sb.drawimage("FTPKA0",coords,gzflags|sb.DI_ITEM_CENTER_BOTTOM,scale:(1.1,1.1));
		int barh=int(24.*fuel/LOR_PACKFUEL);
		sb.fill(color(255,240,130,30),coords.x+14,coords.y-barh,3,barh,gzflags);
		sb.drawstring(
			sb.pnewsmallfont,sb.FormatNumber(fuel),
			coords+(10,-7),gzflags|sb.DI_ITEM_CENTER|sb.DI_TEXT_ALIGN_RIGHT,
			Font.CR_ORANGE,scale:(0.5,0.5)
		);
	}

	override inventory CreateTossable(int amt){
		if(!HDPlayerPawn.CheckStrip(owner,self))return null;
		let tossed=LoRFuelPack(owner.spawn("LoRFuelPack",
			(owner.pos.xy,owner.pos.z+owner.height-20),
			ALLOW_REPLACE
		));
		tossed.mags.clear();
		tossed.mags.push(fuel);
		tossed.amount=1;
		LoRFuelPack.WearEffect(owner,90);
		destroy();
		return tossed;
	}
	states{
	spawn:
		TNT1 A 0;
		stop;
	use:
		TNT1 A 0 A_PackTransfer();
		fail;
	}
}

//loadout hook: "lpk" in a loadout string starts you wearing a full pack
class LoRFuelPackLoadout:HDPickup{
	default{
		-hdpickup.fitsinbackpack
		+inventory.isarmor
		hdpickup.refid LORLD_PACK;
		tag "$TAG_LORPACK";
		inventory.maxamount 1;
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(owner){
			for(inventory iii=owner.inv;iii!=null;iii=iii.inv){
				let hdp=hdpickup(iii);
				if(hdp&&hdp.wornlayer==STRIP_BACKPACK)hdp.destroy();
			}
			owner.A_GiveInventory("LoRFuelPackWorn");
		}
		destroy();
	}
}
