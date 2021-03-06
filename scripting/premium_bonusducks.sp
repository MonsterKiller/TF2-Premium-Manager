/* TODO: 
    config option for ducks on backstab/headshot?
    Timer to stop spamming ducks?
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <premium_manager>

#define PLUGIN_EFFECT "bonusducks"
#define SOUND_DUCK "ambient/bumper_car_quack3.wav"

new bool:g_bIsEnabled[MAXPLAYERS+1];


public Plugin:myinfo = {
    name = "Premium -> Bonus Ducks [TF2]",
    author = "Monster Killer",
    description = "Spawns ducks when you would gib someone or they would gib you.",
    version = "1.3",
    url = "http://monsterprojects.org"
};

public OnPluginStart() {
    HookEvent("player_death", Event_PlayerDeath);
    AddCommandListener(Event_PlayerExplode, "explode");
}

public OnAllPluginsLoaded() {
	if(LibraryExists("premium_manager"))
		Premium_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "premium_manager"))
		Premium_Loaded();
}

public OnLibraryRemoved(const String:name[]) {
	if(StrEqual(name, "premium_manager")) {
        for(new i = 1; i <= MaxClients; i++) {
            g_bIsEnabled[i] = false;
        }
    }
}

public Premium_Loaded() {
    Premium_RegEffect(PLUGIN_EFFECT, "Bonus Ducks", Callback_EnableEffect, Callback_DisableEffect, true);
    Premium_AddEffectCooldown(PLUGIN_EFFECT, 5, PREMIUM_COOLDOWN_ENABLE);
}

public OnPluginEnd() {
    if(LibraryExists("premium_manager"))
        Premium_UnRegEffect(PLUGIN_EFFECT);

    RemoveCommandListener(Event_PlayerExplode, "explode");
}

public Callback_EnableEffect(client) {
    g_bIsEnabled[client] = true;
}

public Callback_DisableEffect(client) {
    g_bIsEnabled[client] = false;
}

public OnClientConnected(client) {
    g_bIsEnabled[client] = false;
}

public OnEventShutdown() {
    UnhookEvent("player_death", Event_PlayerDeath);
}

public OnMapStart() {
    PrecacheModel("models/player/gibs/gibs_duck.mdl", true);
    PrecacheSound(SOUND_DUCK, true);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    new String:sWeapon[32];
    GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
    
    if(g_bIsEnabled[attacker] || g_bIsEnabled[client]) {
        new customKill = GetEventInt(event, "customkill");
        if(ShouldGib(sWeapon, customKill, attacker)) {
            CreateTimer(0.1, Timer_DeleteRagdoll, client);
            SpawnGibs(client);
        }
    }
    return Plugin_Continue;
}

public Action:Event_PlayerExplode(client, const String:command[], argc) {
    if(g_bIsEnabled[client]) {
        CreateTimer(0.1, Timer_DeleteRagdoll, client);
        SpawnGibs(client);
    }
}

public Action:Timer_DeleteRagdoll(Handle:Timer, any:client) {
    new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (ragdoll > 0) {
        SetEntPropEnt(client, Prop_Send, "m_hRagdoll", -1);
        RemoveEdict(ragdoll);    
    }
}

ShouldGib(String:sWeapon[], any:customKill, any:attacker) {
    if(StrContains(sWeapon, "pipe", false) > -1)
        return true;
    if(StrContains(sWeapon, "rocket", false) > -1)
        return true;
    if(StrContains(sWeapon, "deflect", false) > -1)
        return true;
    if(((StrContains(sWeapon, "sentrygun", false) > -1) || (StrContains(sWeapon, "wrangler", false) > -1)) && IsLvl3Sentry(attacker))
        return true;
    /*if(customKill == 1) // Headshot
        return true;*/
    /*if(customKill == 2) // Backstab
        return true;*/
    
    return false;
}

IsLvl3Sentry(any:client) {
    new entity = -1;
    while((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
        if(GetEntDataEnt2(entity, FindSendPropInfo("CBaseObject", "m_hBuilder")) == client) {
            return (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3);
        }
    }
    return false;
}

SpawnGibs(any:client, count=10) {
    if(!IsValidEntity(client)) {
        return;
    }

    float pos[3];
    GetClientAbsOrigin(client, pos);
  
    for(new i = 0; i < count; i++) {
        new gib = CreateEntityByName("prop_physics_override");
        
        decl CollisionOffset;
        DispatchKeyValue(gib, "model", "models/player/gibs/gibs_duck.mdl");

        if(DispatchSpawn(gib)) {
            if(IsValidEntity(gib)) {
                CollisionOffset = GetEntSendPropOffs(gib, "m_CollisionGroup");
                SetEntData(gib, CollisionOffset, 1, 1, true);

                new Float:fVel[3];
                fVel[0] = GetRandomFloat(-250.0, 250.0);
                fVel[1] = GetRandomFloat(-250.0, 250.0);
                fVel[2] = GetRandomFloat(100.0, 250.0);
                TeleportEntity(gib, pos, NULL_VECTOR, fVel);
                CreateTimer(10.0, Timer_DeleteOldGib, gib);
            }
        }
    }
    
    PlayDuckSound(client, pos);
}

PlayDuckSound(client, float pos[3]) {
    EmitAmbientSound(SOUND_DUCK, pos, client, 70);	
}

public Action:Timer_DeleteOldGib(Handle:Timer, any:ent) {
    if(IsValidEntity(ent)) {
        AcceptEntityInput(ent, "kill");
    }
}