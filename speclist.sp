#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define MAX_SPECS 10

enum {
	ALIVE = 0,
	DEAD
};

char g_szSpecPanel[MAXPLAYERS+1][2048];
float g_fLastRefresh[MAXPLAYERS+1];
bool g_bStealth[MAXPLAYERS+1]
	 , g_bSpeclist[MAXPLAYERS+1];

public void OnPluginStart() {
	RegAdminCmd("sm_stealth", Admin_Stealth, ADMFLAG_GENERIC, "Toggle stealth to speclist");
	RegConsoleCmd("sm_speclist", Client_Speclist, "Toggle speclist");
}

public Action Admin_Stealth(int client, int args) {
	g_bStealth[client] = !g_bStealth[client];
	PrintToChat(client, "You are now %s on speclist", g_bStealth[client] ? "\x03HIDDEN\x01" : "\x03SHOWN\x01");
	return Plugin_Handled;
}

public Action Client_Speclist(int client, int args) {
	g_bSpeclist[client] = !g_bSpeclist[client];
	PrintToChat(client, "Speclist is now %s", g_bSpeclist[client] ? "\x03HIDDEN\x01" : "\x03SHOWN\x01");
}

public void OnPlayerPreThink(client ){
	if((GetGameTime() - g_fLastRefresh[client]) >= 0.5){
		FormatSpecList(client, IsPlayerAlive(client) ? ALIVE : DEAD);
		
		g_fLastRefresh[client] = GetGameTime();
	}
}

void FormatSpecList(int client, int iMode=ALIVE) {
	if(GetClientMenu(client) != MenuSource_None || g_bSpeclist[client])
		return;
	
	int iSpecMode;
	int iTarget;
	int iC=0;
	int iTotal=0;
	char sName[64];
	char sSpecs[1024];
	FormatEx(g_szSpecPanel[client], 1024, "");
	
	if(iMode == DEAD) {
		iSpecMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(iSpecMode == 4 || iSpecMode == 5) {
			int iAliveTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			
			if(!(1 <= iAliveTarget <= MaxClients) || !IsClientConnected(iAliveTarget) || IsFakeClient(iAliveTarget))
				return;

			bool bStop=false;

			for(int i = 1 ; i <= MaxClients ; i++) {
				if(!bStop && IsClientInGame(i) && !IsFakeClient(i) && !IsPlayerAlive(i)) {
					iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

					if(iSpecMode == 4 || iSpecMode == 5) {
						iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

						if(iTarget == iAliveTarget) {
							iTotal++;

							if(iC<MAX_SPECS) {
								GetClientName(i, sName, sizeof sName);
								iC++;

								Format(sSpecs, 1024, "%s%s\n", sSpecs, sName);
							}

						} 
						if (iC == MAX_SPECS) {
							Format(sSpecs, 1024, "%s...and %d more", sSpecs, (iTotal-MAX_SPECS));
							bStop=true;
						}
					}
				}
			}
			if(iC && IsClientInGame(iAliveTarget)) {
				GetClientName(iAliveTarget, sName, sizeof sName);
				
				Format(g_szSpecPanel[client], 1024, "Spectating %s\n\n", sName);

				ShowSpectators(client);
			}
			else
				Format(g_szSpecPanel[client], 1024, ""); 
		}
	}
	else if(iMode == ALIVE) {
		for(int i = 1 ; i <= MaxClients ; i++) {
			if(IsClientInGame(i) && !IsFakeClient(i) && !IsPlayerAlive(i)) {      
				iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if(iSpecMode == 4 || iSpecMode == 5) {    
					iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget"); 
					if(iTarget == client) {
						iTotal++;
						
						if(iC<MAX_SPECS) {
							GetClientName(i, sName, sizeof sName);
							iC++;
							
							Format(sSpecs, 1024, "%s%s\n", sSpecs, sName);
						}

					} 
					if (iC==MAX_SPECS) {
						Format(sSpecs, 1024, "%s...and %d more", sSpecs, (iTotal-MAX_SPECS));
						break;
					}
				}         
			}   
		} 
		if(iC)
			Format(g_szSpecPanel[client], 1024, "Specs:\n\n%s ",sSpecs);
		else
			Format(g_szSpecPanel[client], 1024, "Specs:"); 
		
		if(strlen(g_szSpecPanel[client])>3)
			ShowSpectators(client);
	}
}

void ShowSpectators(client) {
	if(strlen(g_szSpecPanel[client])) {
		hud_message(client, "4", "154, 205, 255", "154, 205, 255", "0", "0.3", "0.3", "1.0", "0.5", g_szSpecPanel[client], "0.03", "0.06");
	}
}

public void OnClientDisconnect(client) {
	SDKUnhook(client, SDKHook_PreThinkPost, OnPlayerPreThink);
	g_bSpeclist[client] = false;
	g_fLastRefresh[client] = GetGameTime();
}

public void OnClientPutInServer(client) {
	SDKHook(client, SDKHook_PreThinkPost, OnPlayerPreThink);
	g_bSpeclist[client] = false;
	g_fLastRefresh[client] = GetGameTime();
	g_bStealth[client] = false;
}

stock hud_message(client, char[] channel, char[] color, char[] color2, char[] effect, char[] fadein, char[] fadeout, char[] fxtime, char[] holdtime, char[] message, char[] x, char[] y) {
	int ent = CreateEntityByName("game_text");
	DispatchKeyValue(ent, "channel", channel);
	DispatchKeyValue(ent, "color", color);
	DispatchKeyValue(ent, "color2", color2);
	DispatchKeyValue(ent, "effect", effect);
	DispatchKeyValue(ent, "fadein", fadein);
	DispatchKeyValue(ent, "fadeout", fadeout);
	DispatchKeyValue(ent, "fxtime", fxtime);         
	DispatchKeyValue(ent, "holdtime", holdtime);
	DispatchKeyValue(ent, "message", message);
	DispatchKeyValue(ent, "spawnflags", "0"); //1 = show for all players
	DispatchKeyValue(ent, "x", x);
	DispatchKeyValue(ent, "y", y);         
	DispatchSpawn(ent);
	SetVariantString("!activator");
	
	AcceptEntityInput(ent, "display", client);
	
	char sHold[64];
	FormatEx(sHold, sizeof(sHold), "!self,Kill,,%s,-1", holdtime);
	
	DispatchKeyValue(ent, "OnUser1", sHold);
	AcceptEntityInput(ent, "FireUser1");
}