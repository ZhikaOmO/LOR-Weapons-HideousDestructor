// ------------------------------------------------------------
// Spawn replacement. Runs late (order 1000) so it sees what other
// mods have decided, and only intercepts the vanilla originals.
//   Plasma Rifle -> Incinerator     BFG9000  -> Calamity Blade
//   Cell         -> Fuel Can        CellPack -> Fuel Tank
// Percentages are per-item sliders in Options.
// ------------------------------------------------------------
class LoRHandler:EventHandler{
	//compat registry from LORCOMPAT lumps: "weaponclass statusindex max"
	Array<name> compatClass;
	Array<int> compatIndex;
	Array<int> compatMax;
	int flamecount; //live flames, recounted once a second (see LoRFlame.A_FlameHit)
	static int FlameLoad(){
		let h=LoRHandler(EventHandler.Find("LoRHandler"));
		return h?h.flamecount:0;
	}
	override void OnRegister(){
		SetOrder(1000);
		int lmp=-1;
		while(-1!=(lmp=Wads.FindLump("LORCOMPAT",lmp+1,Wads.GlobalNamespace))){
			string txt=Wads.ReadLump(lmp);
			txt.Replace("\r","\n");
			txt.Replace("\t"," ");
			Array<string> lines;
			txt.Split(lines,"\n");
			for(int i=0;i<lines.size();i++){
				string ln=lines[i];
				int cm=ln.IndexOf("//");
				if(cm>=0)ln=ln.Left(cm);
				Array<string> tk;
				ln.Split(tk," ",TOK_SKIPEMPTY);
				if(tk.size()<3)continue;
				compatClass.push(tk[0]);
				compatIndex.push(tk[1].ToInt());
				compatMax.push(tk[2].ToInt());
			}
		}
	}
	//a worn pack tops up the held weapon of any registered flamethrower
	override void WorldTick(){
		//once a second: recount live flames so lingering fire can scale down under heavy load
		if(!(level.time%35)){
			int n=0;
			let it=ThinkerIterator.Create("LoRFlame");
			while(it.Next())n++;
			flamecount=n;
		}
		//compat feeding is throttled to every 4th tic, 8 units at a time
		if(!compatClass.size()||(level.time&3))return;
		for(int p=0;p<MAXPLAYERS;p++){
			if(!playeringame[p])continue;
			let pl=players[p].mo;
			if(!pl)continue;
			let rw=HDWeapon(players[p].readyweapon);
			if(!rw||rw is "LoRFuelWeapon")continue;
			let pk=LoRFuelPackWorn.Find(pl);
			if(!pk||pk.fuel<1)continue;
			for(int c=0;c<compatClass.size();c++){
				bool match=false;
				for(class<Object> k=rw.GetClass();k;k=k.GetParentClass()){
					if(k.GetClassName()==compatClass[c]){match=true;break;}
				}
				if(!match)continue;
				int idx=compatIndex[c];
				int room=compatMax[c]-rw.weaponstatus[idx];
				if(room>0){
					int got=LoRFuelPackWorn.Draw(pl,min(room,8));
					rw.weaponstatus[idx]+=got;
				}
				break;
			}
		}
	}
	bool Roll(string cvarname){
		let cv=CVar.FindCVar(cvarname);
		if(!cv)return false;
		int pct=cv.GetInt();
		if(pct<=0)return false;
		return random(1,100)<=pct;
	}
	override void CheckReplacement(ReplaceEvent e){
		if(!e.Replacee)return;
		name rn=e.Replacee.GetClassName();
		if(rn=='PlasmaRifle'){
			if(Roll("lor_inc_spawn")){e.Replacement="LoRIncinerator";e.IsFinal=true;}
		}else if(rn=='BFG9000'){
			if(Roll("lor_cbl_spawn")){e.Replacement="LoRCalamityBlade";e.IsFinal=true;}
		}else if(rn=='Cell'){
			if(Roll("lor_can_spawn")){e.Replacement="LoRFuelCanSpawn";e.IsFinal=true;}
		}else if(rn=='WildBackpack'||rn=='Backpack'){
			if(Roll("lor_pack_spawn")){e.Replacement="LoRFuelPack";e.IsFinal=true;}
		}else if(rn=='CellPack'){
			if(Roll("lor_tank_spawn")){e.Replacement="LoRFuelTank";e.IsFinal=true;}
		}
	}
}
