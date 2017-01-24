// new Handle:hCvarSpawnAttemptInterval;

SpawnQueue_OnModuleStart() {
	// hCvarSpawnAttemptInterval = CreateConVar( "ss_spawn_attempt_interval", "0.3", "Time between spawn attempts for a particular SI", FCVAR_PLUGIN, true, 0.1 );
}

GenerateSpawns() {
	if( CountSpecialInfectedBots() < GetConVarInt(hSILimit) ) { // spawn when infected count hasn't reached limit
		new size;
		new numAllowedSI = GetConVarInt(hSILimit) - CountSpecialInfectedBots();
		if( GetConVarInt(hSpawnSize) > numAllowedSI ) { // prevent amount of special infected from exceeding SILimit
			size = numAllowedSI;
		} else {
			size = GetConVarInt(hSpawnSize);
		}
		
		new index;
		new SpawnQueue[SI_HARDLIMIT];
		for( new i = 0; i < SI_HARDLIMIT; i++ ) {
			SpawnQueue[i] = -1;
		}
		
		// generate the spawn queue
		for( new i = 0; i < size; i++ ) {
			index = GenerateIndex();
			if (index == -1) {
				break;
			}
			SpawnQueue[i] = index;
		}
		
		for( new i = 0; i < SI_HARDLIMIT; i++ ) {
			if( SpawnQueue[i] < 0 ) { // end of spawn queue (does not always fill the whole array)
				break;
			}
			AttemptSpawnAuto(SpawnQueue[i]);
		}
	}
}

GenerateIndex() {
	// refresh current SI counts
	SITypeCount();
	
	new TotalSpawnWeight, StandardizedSpawnWeight;
	
	// temporary spawn weights factoring in SI spawn limits
	decl TempSpawnWeights[NUM_TYPES_INFECTED];
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		if( SpawnCounts[i] < GetConVarInt(hSpawnLimits[i]) ) {
			if( GetConVarBool(hScaleWeights) ) {
				TempSpawnWeights[i] = ( GetConVarInt(hSpawnLimits[i]) - SpawnCounts[i] ) * GetConVarInt(hSpawnWeights[i]);
			} else {
				TempSpawnWeights[i] = GetConVarInt(hSpawnWeights[i]);
			}
		} else {
			TempSpawnWeights[i] = 0;
		}
		TotalSpawnWeight += TempSpawnWeights[i];
	}
	
	//calculate end intervals for each spawn
	new Float:unit = 1.0/TotalSpawnWeight;
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		if (TempSpawnWeights[i] >= 0) {
			StandardizedSpawnWeight += TempSpawnWeights[i];
			IntervalEnds[i] = StandardizedSpawnWeight * unit;
		}
	}
	
	new Float:random = GetRandomFloat( 0.0, 1.0 ); //selector r must be within the ith interval for i to be selected
	for (new i = 0; i < NUM_TYPES_INFECTED; i++) {
		//negative and 0 weights are ignored
		if( TempSpawnWeights[i] <= 0 ) continue;
		//r is not within the ith interval
		if( IntervalEnds[i] < random ) continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

SITypeCount() { //Count the number of each SI ingame
	for (new i = 0; i < NUM_TYPES_INFECTED; i++) {
		SpawnCounts[i] = 0;
	}
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) ) {
			switch( L4D2_Infected:GetEntProp(i, Prop_Send, "m_zombieClass") ) {//detect SI type
				case L4D2Infected_Smoker:
					SpawnCounts[_:L4D2Infected_Smoker - 1]++;
				
				case L4D2Infected_Boomer:
					SpawnCounts[_:L4D2Infected_Boomer - 1]++;
				
				case L4D2Infected_Hunter:
					SpawnCounts[_:L4D2Infected_Hunter - 1]++;
				
				case L4D2Infected_Spitter:
					SpawnCounts[_:L4D2Infected_Spitter - 1]++;
				
				case L4D2Infected_Jockey:
					SpawnCounts[_:L4D2Infected_Jockey - 1]++;
				
				case L4D2Infected_Charger:
					SpawnCounts[_:L4D2Infected_Charger - 1]++;
				
				default:
					break;
			}
		}
	}
}

stock AttemptSpawnAuto(classIndex) {
	new String:zombieClassName[16];
	zombieClassName = Spawns[classIndex];
	// Create a client if necessary to circumvent the 3 SI limit
	new iSpawnedSpecialsCount = CountSpecialInfectedBots();
	if( iSpawnedSpecialsCount >= VANILLA_COOP_SI_LIMIT ) {
	    new String:sBotName[32];
	    Format(sBotName, sizeof(sBotName), "Dummy %s", zombieClassName);
	    new bot = CreateFakeClient(sBotName); 
	    if (bot != 0) {
	        ChangeClientTeam(bot, _:L4D2Team_Infected);
	        CreateTimer(0.1, Timer_KickBot, bot, TIMER_FLAG_NO_MAPCHANGE);
	    }
	}
	// Spawn with z_spawn_old using 'auto' parameter to let the Director find a spawn position  
	CheatCommand("z_spawn_old", zombieClassName, "auto", true);
}