//---------------------------------------------------------------------------------------
//  FILE:   YellowAlert_X2DownloadableContentInfo.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class YellowAlert_X2DownloadableContentInfo extends X2DownloadableContentInfo config(YellowAlert);

`include(YellowAlert\Src\extra_globals.uci)

var config array<name> DefensiveReflexAbilities;

static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	InitializePodManager(StartGameState);
}

static function InitializePodManager(XComGameState StartGameState)
{
	local XComGameState_LWPodManager PodManager;

	PodManager = XComGameState_LWPodManager(StartGameState.CreateNewStateObject(class'XComGameState_LWPodManager'));
	`Log("Created pod manager");
}

exec function LWDebugPodJobs()
{
	local XComGameState_LWPodManager PodMgr;
	
	PodMgr = `LWPODMGR;

	PodMgr.bDebugPodJobs = !PodMgr.bDebugPodJobs;
}

exec function LWActivatePodJobs()
{
	local XComGameState NewGameState;
	local XComGameState_LWPodManager PodMgr;
	local XGAIPlayer AIPlayer;
	local Vector XComLocation;
	local float Rad;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: LWActivatePodJobs");
	PodMgr = XComGameState_LWPodManager(NewGameState.CreateStateObject(class'XComGameState_LWPodManager', `LWPODMGR.ObjectID));
	NewGameState.AddStateObject(PodMgr);
	PodMgr.AlertLevel = `ALERT_LEVEL_RED;

	AIPlayer = XGAIPlayer(XGBattle_SP(`BATTLE).GetAIPlayer());
	AIPlayer.GetSquadLocation(XComLocation, Rad);
	PodMgr.LastKnownXComPosition = XComLocation;
	`TACTICALRULES.SubmitGameState(NewGameState);
}

static event OnPostTemplatesCreated()
{
	AddReflexActions();
}

static function AddReflexActions()
{
	local X2AbilityTemplateManager			AbilityManager;
	local name								AbilityName;
	local X2AbilityTemplate					Template;

	AbilityManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	foreach default.DefensiveReflexAbilities(AbilityName)
	{
		Template = AbilityManager.FindAbilityTemplate(AbilityName);
		if (Template != none)
		{
			AddReflexActionPoint(Template, class'YellowAlert_UIScreenListener'.const.DefensiveReflexAction);
		}
		else
		{
		`Log("Cannot add reflex ability " $ AbilityName $ ": Is not a valid ability");
		}
		
	}
	/*  Prefer to use standard action point for offensive reactions because of all the new custom enemy types in WOTC
		It will allow the AI to choose from their own abilities without having to list every one in the .ini
	foreach default.OffensiveReflexAbilities(AbilityName)
	{
		Template = AbilityManager.FindAbilityTemplate(AbilityName);
		if (Template != none)
		{
			AddReflexActionPoint(Template, class'YellowAlert_UIScreenListener'.const.OffensiveReflexAction);
		}
		else
		{
		`Log("Cannot add reflex ability " $ AbilityName $ ": Is not a valid ability");
		}
		
	}*/
}

static function AddReflexActionPoint(X2AbilityTemplate Template, Name ActionPointName)
{
    local X2AbilityCost_ActionPoints        ActionPointCost;
    local X2AbilityCost                     Cost;

    foreach Template.AbilityCosts(Cost)
    {
        ActionPointCost = X2AbilityCost_ActionPoints(Cost);
        if (ActionPointCost != none)
        {
            ActionPointCost.AllowedTypes.AddItem(ActionPointName);
            `Log("Adding reflex action point " $ ActionPointName $ " to " $ Template.DataName);
            return;
        }
    }

    `Log("Cannot add reflex ability " $ Template.DataName $ ": Has no action point cost");
}

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{}