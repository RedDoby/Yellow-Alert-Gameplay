// This is an Unreal Script
class YellowAlert_UIScreenListener extends UIScreenListener Config(YellowAlert);

`include(YellowAlert\Src\extra_globals.uci)

var config bool EnableAItoAIActivation;
var config bool AllowBonusReflexActions;
var config bool bRapidReinforcements;
var config bool bAlwaysDefend; //If true units will always receive a defensive action point rather than an offensive
var config bool bReinforcementsAlwaysDefend;
var config int NumTurnsIncreaseCountdown;
var config bool DisableFirstTurn;

var config float REFLEX_ACTION_CHANCE_YELLOW;
var config float REFLEX_ACTION_CHANCE_GREEN;
var config float REFLEX_ACTION_CHANCE_REINFORCEMENT;
var config float DISTANCE_MOVED_MODIFIER;
var config float REFLEX_ACTION_CHANCE_REDUCTION;
var config float COUNTERATTACKMODIFIER;

const ReinforcementUnitValue = 'NoReflexAction_LW';
const NoReinforcementUnitValue = 'NoReinforcementUnitValue';
const RefundActionUnitValue = 'RefundActionUnitValue';
const DefensiveRefundActionUnitValue = 'DefensiveRefundActionUnitValue';

//create the array used to store seesalertedally units so that we can check existing prior to adding the new alert
struct AllyAlertData
{
	var int AlertUnitID;
	var int AlertSourceGroupID;
};
var array<AllyAlertData> AllyUnitsSeen;//Used for storing the alerted ally units seen by a unit

// Transient helper vars for alien reflex actions. These are not persisted.
var transient int LastReflexGroupId;          // ObjectID of the last group member we processed
var transient int NumSuccessfulReflexActions; // The number of successful reflex actions we've added for the current pod

event OnInit(UIScreen screen)
{
	//local XComGameState_Player PlayerState;
	local Object ThisObj;
	local X2EventManager EventManager;

	ThisObj = self;
	EventManager = `XEVENTMGR;
	
	//EventManager.RegisterForEvent(ThisObj, 'AbilityActivated', OnAbilityActivated, ELD_OnStateSubmitted, 55); No Longer need since CH fixed
	//Needs to be lower priority than the function in XcomGameState-Unit so the alert can be added to the group first
	EventManager.RegisterForEvent(ThisObj, 'OverrideSoundRange', OnOverrideSoundRange, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'AlertDataTriggerAlertAbility', OnAlertDataTriggerAlertAbility, ELD_OnStateSubmitted, 45);
	EventManager.RegisterForEvent(ThisObj, 'OnEnvironmentalDamage', OnExplosion, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'ReinforcementSpawnerCreated', OnReinforcementSpawnerCreated, ELD_OnStateSubmitted, 55);
	//Needs to be high priority so that it runs prior to the reinforcement spawner listener return
	//since that would cause the reflex move activation to happen prior to marking reinforcement units here
	EventManager.RegisterForEvent(ThisObj, 'SpawnReinforcementsComplete', OnSpawnReinforcementsComplete, ELD_OnStateSubmitted, 55);
	EventManager.RegisterForEvent(ThisObj, 'ChosenSpawnReinforcementsComplete', OnChosenSpawnReinforcementsComplete, ELD_OnStateSubmitted, 55);
	EventManager.RegisterForEvent(ThisObj, 'ProcessReflexMove', RefundActionPoint, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'ScamperEnd', ProcessRefund, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'UnitTakeEffectDamage', OnUnitTookDamage, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'OverrideSeesAlertedAllies', CheckSeesAlertedAlliesAlert, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OverrideEncounterZoneAnchorPoint', DisableEnemiesChasingPlayerPosition, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OnTacticalBeginPlay', DisableInterceptAIBehavior, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OverridePatrolBehavior', DisableDefaultPatrolBehavior, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OnTacticalBeginPlay', OnTacticalBeginPlay, ELD_OnStateSubmitted, 51);
	EventManager.RegisterForEvent(ThisObj, 'AlienTurnBegun', OnAlienTurnBegin, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'UnitGroupTurnBegun', OnUnitGroupTurnBegun, ELD_OnStateSubmitted, 55);
	EventManager.RegisterForEvent(ThisObj, 'AbilityActivated', SetPodManagerAlert, ELD_OnStateSubmitted, 53);
	EventManager.RegisterForEvent(ThisObj, 'PlayerTurnBegun', LW2OnPlayerTurnBegun, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'DrawDebugLabels', OnDrawDebugLabels, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OnMissionObjectiveComplete', OnObjectiveComplete, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'UnitMoveFinished', CheckEvacZoneAlert, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'PodJobConverge', OnPodJobConverge, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObj, 'OverrideAllowedAlertCause', OnOverrideAllowedAlertCause, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OverrideEnemyFactionsAlertsOutsideVision', OnOverrideEnemyFactionsAlertsOutsideVision, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'OverridePatrolDestination', OnOverridePatrolDestination, ELD_Immediate);
	EventManager.RegisterForEvent(ThisObj, 'ShouldCivilianRun', ShouldCivilianRunFromOtherUnit, ELD_Immediate);

	//EventManager.RegisterForEvent(ThisObj, 'XComTurnBegun', PrintAlertData, ELD_OnStateSubmitted, 90);//For debugging alert data
}

event OnRemoved(UIScreen screen)
{
	local Object ThisObj;
	local X2EventManager EventManager;

	ThisObj = self;
	EventManager = `XEVENTMGR;

	EventManager.UnRegisterFromEvent(ThisObj, 'OverrideSoundRange');
	EventManager.UnRegisterFromEvent(ThisObj, 'AlertDataTriggerAlertAbility');
	//EventManager.UnRegisterFromEvent(ThisObj, 'AbilityActivated');
	EventManager.UnRegisterFromEvent(ThisObj, 'OnEnvironmentalDamage');
	EventManager.UnRegisterFromEvent(ThisObj, 'ReinforcementSpawnerCreated');
	EventManager.UnRegisterFromEvent(ThisObj, 'SpawnReinforcementsComplete');
	EventManager.UnRegisterFromEvent(ThisObj, 'ChosenSpawnReinforcementsComplete');
	EventManager.UnRegisterFromEvent(ThisObj, 'ProcessReflexMove');
	EventManager.UnRegisterFromEvent(ThisObj, 'ScamperEnd');
	EventManager.UnRegisterFromEvent(ThisObj, 'UnitTakeEffectDamage');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverrideSeesAlertedAllies');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverrideEncounterZoneAnchorPoint');
	EventManager.UnRegisterFromEvent(ThisObj, 'OnTacticalBeginPlay');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverridePatrolBehavior');
	EventManager.UnRegisterFromEvent(ThisObj, 'AlienTurnBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'UnitGroupTurnBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'PlayerTurnBegun');
	//EventManager.UnRegisterFromEvent(ThisObj, 'XComTurnBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'DrawDebugLabels');
	EventManager.UnRegisterFromEvent(ThisObj, 'OnMissionObjectiveComplete');
	EventManager.UnRegisterFromEvent(ThisObj, 'UnitMoveFinished');
	EventManager.UnRegisterFromEvent(ThisObj, 'PodJobConverge');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverrideAllowedAlertCause');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverrideEnemyFactionsAlertsOutsideVision');
	EventManager.UnRegisterFromEvent(ThisObj, 'OverridePatrolDestination');
	EventManager.UnRegisterFromEvent(ThisObj, 'ShouldCivilianRun');
}

static function EventListenerReturn OnDrawDebugLabels(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local Canvas kCanvas;
	local XComGameState_LWPodManager PodManager;
	
	kCanvas = Canvas(EventData);
	if (kCanvas == none)
		return ELR_NoInterrupt;
	
	PodManager = `LWPODMGR;
	if (PodManager.bDebugPodJobs)
	{
		PodManager.DrawDebugLabel(kCanvas);
	}
	return ELR_NoInterrupt;
}

//Create Seesexplosion alerts (truly it is produced by sound but I am using the default eAC_SeesExplosion) 
function EventListenerReturn OnExplosion(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateHistory History;
	local XComGameState_EnvironmentDamage DamageGameState;
	local Vector DamageLocation;
	local TTile DamageTileLocation;
	local Name DamageType;
	local XComGameState NewGameState;
	local AlertAbilityInfo AlertInfo;
	local XComGameState_Unit kUnitState;
	local XComGameState_AIUnitData NewUnitAIState, kAIData;
	local array<StateObjectReference> AliensInRange;
	local bool CleanupAIData;
	local int Radius;

	DamageGameState = XComGameState_EnvironmentDamage(EventData);
	Radius = DamageGameState.DamageRadius;
	DamageType = DamageGameState.DamageTypeTemplateName;
	//projectiles are grenade launchers - these need to have a radius
	if((DamageType == 'Explosion' || DamageType == 'DefaultProjectile') && DamageGameState.DamageRadius>0)
	{
		//`Log("OnExplosion: Damage type is "@DamageType@" and radius is"@Radius);
	}
	else
	{
	return ELR_NoInterrupt;
	}

	DamageLocation = DamageGameState.HitLocation;
	DamageTileLocation = `XWORLD.GetTileCoordinatesFromPosition(DamageLocation);
	Radius = 28 + (Radius/96);//standard grenades are 30, larger explosions create a larger radius
	//`Log("OnExplosion: Damage tile location found at " $DamageTileLocation.X$","@DamageTileLocation.Y$","@DamageTileLocation.Z);	 

	History = `XCOMHISTORY;
	
	// Kick off mass alert to location.
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState( "Explosion Alert" );

	AlertInfo.AlertTileLocation = DamageTileLocation;
	AlertInfo.AlertRadius = Radius;
	AlertInfo.AlertUnitSourceID = DamageGameState.DamageCause.ObjectID;
	AlertInfo.AnalyzingHistoryIndex = History.GetCurrentHistoryIndex( ); //NewGameState.HistoryIndex; <- this value is -1.

	// Gather the units in sound range of this explosion.
	class'HelpersYellowAlert'.static.GetUnitsInRange(DamageTileLocation, Radius, AliensInRange);

	foreach History.IterateByClassType( class'XComGameState_AIUnitData', kAIData )
	{
		kUnitState = XComGameState_Unit( History.GetGameStateForObjectID( kAIData.m_iUnitObjectID ) );
		if (kUnitState != None && kUnitState.IsAlive( ))
		{
			// LWS Add: Skip units outside of sound range
			if (AliensInRange.Find('ObjectID', kUnitState.ObjectID) < 0)
				continue;
			CleanupAIData = false;
			// LWS: Check to see if we already have ai data for this unit in this game state (alert may already have been propagated to
			// group members).
			NewUnitAIState = XComGameState_AIUnitData(NewGameState.GetGameStateForObjectID(kAIData.ObjectID));
			if (NewUnitAIState == none)
			{
				NewUnitAIState = XComGameState_AIUnitData( NewGameState.CreateStateObject( kAIData.Class, kAIData.ObjectID ) );
				// LWS: This unit will need cleanup if we fail to add the alert.
				CleanupAIData = true;
			}
			if( NewUnitAIState.AddAlertData( kAIData.m_iUnitObjectID, eAC_SeesExplosion, AlertInfo, NewGameState ) )
			{
				NewGameState.AddStateObject(NewUnitAIState);
			}
			else
			{
				// LWS Add: Don't cleanup this AI unit data unless we created it.
				if (CleanupAIData)
				{
					NewGameState.PurgeGameStateForObjectID(NewUnitAIState.ObjectID);
				}
			}
		}
	}

	if( NewGameState.GetNumGameStateObjects() > 0 )
	{
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}

//No Longer needed since CH added
// Gutted version of the function from XComGameState_Unit that includes a small Long War fix.
// This will cause sound alerts to pick for aliens when hear shots coming from other aliens
// Because GetUnitsInRange instead of GetEnemiesInRange
// Runs in addition to the default method since there is no harm in notifying units twice about sounds
//function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
//{
	//local XComGameState_Ability ActivatedAbilityState;
	//local XComGameStateContext_Ability ActivatedAbilityStateContext;
	//local XComGameState_Unit SourceUnitState, EnemyInSoundRangeUnitState;
	//local XComGameState_Item WeaponState;
	//local int SoundRange;
	//local TTile SoundTileLocation;
	//local Vector SoundLocation;
	//local array<StateObjectReference> Enemies;
	//local StateObjectReference EnemyRef;
	//local XComGameStateHistory History;
	//local XComGameState_Unit ThisUnitState;
//
	//ActivatedAbilityStateContext = XComGameStateContext_Ability(GameState.GetContext());
//
	//// do not process concealment breaks or AI alerts during interrupt processing
	//if( ActivatedAbilityStateContext.InterruptionStatus == eInterruptionStatus_Interrupt )
	//{
		//return ELR_NoInterrupt;
	//}
//
	//History = `XCOMHISTORY;
	//ThisUnitState = XComGameState_Unit(EventSource);
	//ActivatedAbilityState = XComGameState_Ability(EventData);
//
	//if( ActivatedAbilityState.DoesAbilityCauseSound() )
	//{
		//if( ActivatedAbilityStateContext != None && ActivatedAbilityStateContext.InputContext.ItemObject.ObjectID > 0 )
		//{
			//SourceUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ActivatedAbilityStateContext.InputContext.SourceObject.ObjectID));
			//WeaponState = XComGameState_Item(GameState.GetGameStateForObjectID(ActivatedAbilityStateContext.InputContext.ItemObject.ObjectID));
//
            //// LWS Mods: If this weapon originates sound at the target and there is source ammo involved, use that sound range. This is needed
            //// for grenade launchers, which have a weapon range of 0, but the ammo is what we want to use for the sound range. Thrown grenades
            //// have no source ammo (the grenade is the weapon, there is no launcher) so we will use the weapon state in the else.
			////Grenade launchers are now picked up as SeesExplosion Alerts
            //if (!WeaponState.SoundOriginatesFromOwnerLocation() && ActivatedAbilityState.GetSourceAmmo() != none)
            //{
                //SoundRange = ActivatedAbilityState.GetSourceAmmo().GetItemSoundRange();
            //}
            //else
            //{
                //SoundRange = WeaponState.GetItemSoundRange();
            //}
//
			//if( SoundRange > 0 )
			//{
				//// Modify sound range for this shot / grenade
				////SoundRange += SoundModifierMin + `SYNC_FRAND() * (SoundModifierMax - SoundModifierMin);
//
				//if( !WeaponState.SoundOriginatesFromOwnerLocation() && ActivatedAbilityStateContext.InputContext.TargetLocations.Length > 0 )
				//{
					//SoundLocation = ActivatedAbilityStateContext.InputContext.TargetLocations[0];
					//SoundTileLocation = `XWORLD.GetTileCoordinatesFromPosition(SoundLocation);
				//}
				//else
				//{
					//ThisUnitState.GetKeystoneVisibilityLocation(SoundTileLocation);
				//}
//
				//// LWS added: Gather the units in sound range of this weapon.
				//class'HelpersYellowAlert'.static.GetUnitsInRange(SoundTileLocation, SoundRange, Enemies);
//
				////`Log("Yellow Alert Weapon sound @ Tile("$SoundTileLocation.X$","@SoundTileLocation.Y$","@SoundTileLocation.Z$") - Found"@Enemies.Length@"enemies in range ("$SoundRange$" meters)");
				//foreach Enemies(EnemyRef)
				//{
					//EnemyInSoundRangeUnitState = XComGameState_Unit(History.GetGameStateForObjectID(EnemyRef.ObjectID));
//
					//// if not targeted, provide sound information
					//if( EnemyInSoundRangeUnitState.ObjectID != ActivatedAbilityStateContext.InputContext.PrimaryTarget.ObjectID )
					//{
						//// this unit just overheard the sound
						//ThisUnitState.UnitAGainsKnowledgeOfUnitBFromLocation(EnemyInSoundRangeUnitState, SourceUnitState, GameState, eAC_DetectedSound, false, SoundTileLocation);
					//}
				//}
			//}
		//}
	//}
//
	//return ELR_NoInterrupt;
//}

// Fixes sound that comes from grenades so it comes from the tile that the grenade hit, not the shooter's tile
static function EventListenerReturn OnOverrideSoundRange(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Item WeaponState;
	local XComGameState_Ability ActivatedAbilityState;
	local int SoundRange;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if (Tuple.Id != 'OverrideSoundRange')
		return ELR_NoInterrupt;

	WeaponState = XComGameState_Item(Tuple.Data[1].o);
	if (WeaponState == None)
	{
		`REDSCREEN("Invalid item state passed to OnOverrideSoundRange");
		return ELR_NoInterrupt;
	}

	ActivatedAbilityState = XComGameState_Ability(Tuple.Data[2].o);
	if (ActivatedAbilityState == None)
	{
		`REDSCREEN("Invalid ability state passed to OnOverrideSoundRange");
		return ELR_NoInterrupt;
	}

	SoundRange = Tuple.Data[3].i;

	// If the sound comes from ammo, like a grenade fired from a grenade launcher, use
	// the ammo's sound range instead of the weapon's.
	if (!WeaponState.SoundOriginatesFromOwnerLocation() && ActivatedAbilityState.GetSourceAmmo() != None)
	{
		SoundRange = ActivatedAbilityState.GetSourceAmmo().GetItemSoundRange();
	}

	Tuple.Data[3].i = SoundRange;

	return ELR_NoInterrupt;
}

// Check incoming red and yellow alerts for AI to AI damage outside of Xcom's vision
function EventListenerReturn OnAlertDataTriggerAlertAbility(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit AlertedUnit, DamagingUnit/*, NewUnitState*/;
	local XComGameState_AIGroup AIGroupState;
	local XComGameState_AIUnitData AIGameState;
	local int AIUnitDataID, AlertDataIndex, DamagingUnitID, DamagingUnitGroupID;
	local AlertData AlertData;
	local EAlertCause AlertCause, AIAlertCause;
	local XComGameStateHistory History;
	local ETeam DamagingUnitTeam, AlertedUnitTeam;
	//local XComGameState NewGameState;
	//local array<int> LivingMembers;
	//local int j;
	if(!EnableAItoAIActivation)//check config if activation is true then continue
	{
		return ELR_NoInterrupt; 
	}

	History = `XCOMHISTORY;

	AlertedUnit = XComGameState_Unit(EventSource);
	AlertedUnitTeam = AlertedUnit.GetTeam();
	
	if( AlertedUnit.IsAlive() )
	{
		AIUnitDataID = AlertedUnit.GetAIUnitDataID();
		if( AIUnitDataID == INDEX_NONE )
		{
			return ELR_NoInterrupt; // This may be a mind-controlled soldier. If so, we don't need to update their alert data.
		}
		AIGameState = XComGameState_AIUnitData(GameState.GetGameStateForObjectID(AIUnitDataID));
		if (AIGameState == none)
		{
		return ELR_NoInterrupt;//end this call instead of asserting
		}
		//AlertData = AIGameState.GetAlertData(0); // Kismet Alerts are sent one at a time, so there is only one entry in the array
//
		//// First lets use this listener to check for incoming Kismet converge alerts so we can remove those from the history
		//if( AlertData.AlertCause == eAC_MapwideAlert_Hostile && AlertData.KismetTag == "Converge" )
		//{
			//NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Deleting Kismet Converge alert Date");
			//NewAIGameState = XComGameState_AIUnitData(NewGameState.ModifyStateObject(class'XComGameState_AIUnitData', AIUnitDataID));
			//NewAIGameState.RemoveAlertDataAtIndex(0);
			//`TACTICALRULES.SubmitGameState(NewGameState);
		//}

		AlertCause = eAC_None;

		if( AIGameState.RedAlertCause == eAC_TakingFire || AIGameState.RedAlertCause == eAC_TookDamage ||
			(AlertCause == eAC_SeesSpottedUnit && class'HelpersYellowAlert'.static.AISeesAIEnabled()) )
		{
			AlertCause = AIGameState.RedAlertCause;
			`Log("Yellow Alert Gameplay: detected Red Alert caused by "@AlertCause@" to unit #"@AlertedUnit.ObjectID);
		}
		else
		{
			return ELR_NoInterrupt; //if red alert cause is None then return
		}

		AIGroupState = AlertedUnit.GetGroupMembership();
		if(AIGroupState != None && !AIGroupState.bProcessedScamper && AlertedUnit.bTriggerRevealAI) //if valid group has not processed scamper and unit is able to scamper continue
		{
			// figure out what unit caused this red alert
			for (AlertDataIndex = AIGameState.GetAlertCount()-1; AlertDataIndex >= 0; AlertDataIndex--) //start with newest alert first
			{
				AlertData = AIGameState.GetAlertData(AlertDataIndex);
				AIAlertCause = AlertData.AlertCause;
				if (AIAlertCause == AlertCause )//match alert history with the red alert cause
				{
					DamagingUnitID = AlertData.AlertSourceUnitID;
					DamagingUnit = XComGameState_Unit(History.GetGameStateForObjectID(DamagingUnitID));
					DamagingUnitTeam = DamagingUnit.GetTeam();
					DamagingUnitGroupID = DamagingUnit.GetGroupMembership().ObjectID;
					`Log("Yellow Alert Gameplay: found AI to AI "@AIAlertCause@" Alert from team: "@DamagingUnitTeam@", unit #"@DamagingUnitID@" to team: "@AlertedUnitTeam@", unit #"@AlertedUnit.ObjectID);
						
					if(DamagingUnitTeam != eTeam_XCom && AlertedUnitTeam != DamagingUnitTeam ) //only processing ai to ai damages from different teams here
					{  
						//We will need to assign a special value to mark that these are not reinforcements since they will be process their reflex move in yellow alert
						//NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Processing AI to AI Reflex Move Activations outside of XCom's Vision");
						//AIGroupState.GetLivingMembers(LivingMembers);
						//for (j = 0; j < LivingMembers.Length; ++j)
						//{
							//NewUnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', LivingMembers[j]));
							//NewUnitState.SetUnitFloatValue(NoReinforcementUnitValue, 1, eCleanup_BeginTurn);
						//}
						//`TACTICALRULES.SubmitGameState(NewGameState);
						AIGroupState.InitiateReflexMoveActivate(DamagingUnit, AIAlertCause);
						`Log("Yellow Alert Gameplay: Activating Ai group on team "@AlertedUnitTeam@", group #"@AIGroupState.ObjectID@" caused by AI team "@DamagingUnitTeam@", group #"@DamagingUnitGroupID);
					}
					break; //source unit found, end loop
				}
			}
			
		}
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnReinforcementSpawnerCreated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_AIReinforcementSpawner Spawner, NewSpawnerState;

	Spawner = XComGameState_AIReinforcementSpawner(EventSource);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Change Reinforcement Variables");
	NewSpawnerState = XComGameState_AIReinforcementSpawner(NewGameState.ModifyStateObject(class'XComGameState_AIReinforcementSpawner', Spawner.ObjectID));
	if (bRapidReinforcements)
	{
		if (NewSpawnerState.SpawnVisualizationType == 'ATT' || NewSpawnerState.SpawnVisualizationType == 'PsiGate' || Spawner.SpawnVisualizationType == 'Dropdown')
		{
			// Removal of the forced spawning in XCom LOS
			if(NewSpawnerState.bMustSpawnInLOSOfXCOM)
			{		
				`log("Yellow Alert Gameplay found a reinforcement that must spawn within LOS of XCom, setting to false");
				NewSpawnerState.bMustSpawnInLOSOfXCOM = false;
			}
		}
	}		 
	// Enable increase of the countdown
	if (NumTurnsIncreaseCountdown > 0)
	{
		NewSpawnerState.Countdown += NumTurnsIncreaseCountdown;
	}
	if(NewGameState.GetNumGameStateObjects() > 0)
		{
			`TACTICALRULES.SubmitGameState(NewGameState);
		}
		else
		{
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		}

	return ELR_NoInterrupt;
}


// A RNF pod has spawned. Mark the units with a special marker to indicate that they are reinforcements
// If rapid reinforcements is enabled then allow groups spawning outside of Xcom's vision to move this turn by setting bSummoningSicknessCleared = true
function EventListenerReturn OnSpawnReinforcementsComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState_AIGroup Group;
	local XComGameState NewGameState;
	local XComGameState_AIReinforcementSpawner Spawner, NewSpawnerState;
	local int i;

	Spawner = XComGameState_AIReinforcementSpawner(EventSource);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Check for Reinforcement Units");

	// First, modify any reinforcements spawns that are ATT, PsiGate or DropDown so that they don't force scamper
	if (bRapidReinforcements)
	{
		if (Spawner.SpawnVisualizationType == 'ATT' || Spawner.SpawnVisualizationType == 'PsiGate' || Spawner.SpawnVisualizationType == 'Dropdown')
		{
			if(Spawner.bForceScamper)
			{
				// Modify this spawner state
				NewSpawnerState = XComGameState_AIReinforcementSpawner(NewGameState.ModifyStateObject(class'XComGameState_AIReinforcementSpawner', Spawner.ObjectID));	
				`log("Yellow Alert Gameplay found a reinforcement with forced scamper, setting to false");
				NewSpawnerState.bForceScamper = false;
			}
		}
	}		 

	for (i = 0; i < Spawner.SpawnedUnitIDs.Length; ++i)
	{
		// First set special value to mark reinforcement units
		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Spawner.SpawnedUnitIDs[i]));
		Unit.SetUnitFloatValue(ReinforcementUnitValue, 1, eCleanup_BeginTurn);
	}
	Group =	Unit.GetGroupMembership();
	// if group is valid, has not processed scamper and rapid reinforcements is enabled
	// There are times when this listener is called prior to processreflex move and times when it gets called after.  
	// If it's called after we need to have this check so that they don't move again after scamper.  
	// If this is called first and the units are scampering the summoning sickness is uncleared during the process reflex move so it doesn't matter if we set it to true anyway.
	// Add an exeption for ETeam_One - which is the hive.  They are already too OP as it is
	if (Group != None && Group.TeamName != eTeam_One && !Group.bProcessedScamper && bRapidReinforcements) 
	{	
		`log("Yellow Alert Gameplay found a reinforcement group that hasn't processeed scamper");
		Group = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', Group.ObjectID));
		//This flag allows reinforcement units take a full turn on the same turn that they spawn outside Xcom vision
		//Vanilla behavior skips their current turn and waits until the aliens next turn before they can take their first move
		Group.bSummoningSicknessCleared = true;  
	} 
	`TACTICALRULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

// A RNF pod has spawned from the Chosen. Mark the units with a special marker to indicate that they are reinforcements
// If rapid reinforcements is enabled then allow groups spawning outside of Xcom's vision to move this turn by setting bSummoningSicknessCleared = true
function EventListenerReturn OnChosenSpawnReinforcementsComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState_AIGroup Group;
	local XComGameState NewGameState;
	local int i;
	local array<int> LivingMembers;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Check for Reinforcement Units"); 
	Group =	XComGameState_AIGroup(EventData);
	Group.GetLivingMembers(LivingMembers);

	for (i = 0; i < LivingMembers.Length; ++i)
	{
		// First set special value to mark reinforcement units
		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', LivingMembers[i]));
		Unit.SetUnitFloatValue(ReinforcementUnitValue, 1, eCleanup_BeginTurn);
	}

	`TACTICALRULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

function EventListenerReturn RefundActionPoint(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_AIGroup GroupState;
	local array<int> LivingMembers;
	local XComGameState_Unit LeaderState, Member, PreviousUnit;
	local ETeam LeaderTeam;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameStateHistory History;
	local X2TacticalGameRuleset Rules;
	local int j, TilesMoved, PathIndex, i;
	local bool IsGreen, IsYellow, IsReinforcementGroup, bFoundMovement;
    local float Chance, Roll, fTileMoveRange, OneMovementAction;
	local UnitValue Value/*, ValueX*/;
	local XComGameState_Player PlayerState;
	local TTile TestTile;
	local XComGameState_AIPlayerData AIData;
	local XGAIPlayer AIPlayer;

		// Note: We don't currently support reflex actions on XCOM's turn. Doing so requires
	// adjustments to how scampers are processed so the units would use their extra action
	// point. Also note that giving units a reflex action point while it's not their turn
	// can break stun animations unless those action points are used: see X2Effect_Stunned
	// where action points are only removed if it's the units turn, and the effect actions
	// (including the stunned idle anim override) are only visualized if the unit has no
	// action points left. If the unit has stray reflex actions they haven't used they
	// will stand back up and perform the normal idle animation (although they are still
	// stunned and won't act).

	GroupState = XComGameState_AIGroup(EventSource);
	History = `XCOMHISTORY;
	Rules = `TACTICALRULES;
	GroupState.GetLivingMembers(LivingMembers);
	LeaderState = XComGameState_Unit(History.GetGameStateForObjectID(LivingMembers[0]));
	LeaderTeam = LeaderState.GetTeam();
	`Log(GetFuncName() $ ": Processing reflex move for Leader " $ LeaderState.GetMyTemplateName());
	PlayerState = XComGameState_Player(History.GetGameStateForObjectID(LeaderState.ControllingPlayer.ObjectID));

	if(!AllowBonusReflexActions)
	{
		 return ELR_NoInterrupt;
	}
	
	if (DisableFirstTurn && PlayerState.PlayerTurnCount == 1)
	{
		`Log(GetFuncName() $ ": First turn reflex reactions are disabled: aborting");
		return ELR_NoInterrupt;
	}
	// Add an exeption for the lost and ETeam_One (The Hive) and the Chosen
	if (LeaderTeam == eTeam_TheLost || LeaderTeam == eTeam_One || LeaderState.IsChosen())
	{
		`Log(GetFuncName() $ ": The lost, Eteam_One (The Hive), and the Chosen aren't eligible for reflex reactions: aborting");
		return ELR_NoInterrupt;
	}

    if (LeaderTeam != Rules.GetUnitActionTeam())
    {
        `Log(GetFuncName() $ ": Not the "$LeaderTeam$" team's turn: aborting");
        return ELR_NoInterrupt;
    }
	// Ignore shadow bound units
	if (Left(string(LeaderState.GetMyTemplateName()), 14) == "ShadowbindUnit")
	{
		 `Log(GetFuncName() $ ": ShadowbindUnit: aborting");
        return ELR_NoInterrupt;
	}

    if (GroupState == none)
    {
        `Log(GetFuncName() $ ": Can't find group: aborting");
        return ELR_NoInterrupt;
    }

	// Look for the special 'NoReflexAction' unit value. If present, this unit isn't allowed to take an action.
	// This is typically set on reinforcements on the turn they spawn. But if they spawn out of LoS they are
	// eligible, just like any other yellow unit, on subsequent turns. Both this check and the one below are needed.
	LeaderState.GetUnitValue(ReinforcementUnitValue, Value);
	IsReinforcementGroup = false;

 	if (Value.fValue == 1)
	{	
		if(!bRapidReinforcements)//If Rapid reinforcements are disabled then don't allow reflex actions for these groups
		{
			`Log(GetFuncName() $ ": Reinforcement Unit marked with no action value: aborting");
			return ELR_NoInterrupt;
		}
		else
		{
			`Log(GetFuncName() $ ": Reinforcement Unit marked with value: continuing");
			IsReinforcementGroup = true;//Mark this as a reinforcement group
		}
	}
	
	// Walk backwards through history for this unit until we find a state in which this unit wasn't in red
	// alert to see if we entered from yellow or from green. Skip this check if it is a reinforcement unit
	if (!IsReinforcementGroup)
	{
		PreviousUnit = LeaderState;

		while (PreviousUnit != none && PreviousUnit.GetCurrentStat(eStat_AlertLevel) > 1)
		{
			PreviousUnit = XComGameState_Unit(History.GetPreviousGameStateForObject(PreviousUnit));
		}

		if (PreviousUnit != none)
		{ 
			if (PreviousUnit.GetCurrentStat(eStat_AlertLevel) == 1)
			{
				IsYellow = true;
			}
			if (PreviousUnit.GetCurrentStat(eStat_AlertLevel) == 0)
			{
				IsGreen = true;
			}
		}
		else 
		{
			`Log(GetFuncName() $ ": No previous history found for this unit to determine the alert level");
		}
	}
    // Did our current pod change? If so reset the number of successful reflex actions we've had so far.
    if (GroupState.ObjectID != LastReflexGroupID)
    {
        NumSuccessfulReflexActions = 0;
        LastReflexGroupId = GroupState.ObjectID;
    }
	
	for (j = 0; j < LivingMembers.Length; ++j)
	{
		Member = XComGameState_Unit(GameState.ModifyStateObject(class'XComGameState_Unit', LivingMembers[j]));

		If (!Member.CanScamper())
		{
			`Log(GetFuncName() $ ": Skipping unit# "$Member.ObjectID$" because it can't scamper");
			continue; //skip this unit if it can't scamper
		}
	
		TilesMoved = 0;
		bFoundMovement = false;
		fTileMoveRange = `METERSTOTILES(Member.GetCurrentStat(eStat_Mobility));

		// If unit is scampering and hasn't moved yet we can skip the counting movement tiles
		if (Member.TileLocation == Member.TurnStartLocation)
		{
			//`Log(GetFuncName()@" Start Tile: " @Member.TurnStartLocation.x@", "@Member.TurnStartLocation.y@" is the same as current tile, unit hasn't moved");
		}
		else
		{
			// Walk backwards through history to see if this unit moved since the last turn
			// if they didn't take a full movement then they will have a chance to get an extra action point
			AIPlayer = XGAIPlayer(XGBattle_SP(`BATTLE).GetAIPlayer());
			AIData = XComGameState_AIPlayerData(History.GetGameStateForObjectID(AIPlayer.GetAIDataID()));

			foreach History.IterateContextsByClassType( class'XComGameStateContext_Ability', AbilityContext, , , AIData.m_iLastEndTurnHistoryIndex )
			{
				if( AbilityContext.GetMovePathIndex(Member.ObjectID) >= 0)
				{
					PathIndex = AbilityContext.GetMovePathIndex(Member.ObjectID);
					bFoundMovement = true;
					//`Log(GetFuncName()@" Start Tile: " @Member.TurnStartLocation.x@", "@Member.TurnStartLocation.y);
					// Loop through each tile moved until we find the one that equals the units current location, this will give us the tiles moved
					// Start at the second array item, the first location is the start tile
					for (i = 1; i < AbilityContext.InputContext.MovementPaths[PathIndex].MovementTiles.Length; ++i)
					{	
						TestTile = AbilityContext.InputContext.MovementPaths[PathIndex].MovementTiles[i];
						//`Log(GetFuncName() $ ": " $TestTile.X$", "$TestTile.Y);
						if( TestTile == Member.TileLocation )
						{
							TilesMoved = i;
							break;
						}
					}
					break;
				}
			}
			if (bFoundMovement)
			{
				`Log(GetFuncName() $ ": Found a Move this turn for Unit#"@Member.ObjectID@" "$Member.GetMyTemplateName()$", tiles moved: " @TilesMoved@ " move range in tiles: "@fTileMoveRange);
				// If unit is advent and counterattack dark event is active, then we need to increase the allowed movement range by the modifier
				// So that they can be elligble for further reflex actions
				if(Member.IsAdvent() && IsDarkEvent_CounterattackActive())
				{	
					OneMovementAction = (1 + COUNTERATTACKMODIFIER) * fTileMoveRange;
					`Log(GetFuncName() $ ": Unit is advent and Dark Event Counter Attack is active, multiplying move modifier");
				}
				else 
				{
					OneMovementAction = fTileMoveRange;
				}
				if(TilesMoved >= OneMovementAction)
				{
					`Log(GetFuncName() $ ": Unit has already moved at least "$OneMovementAction$" tiles this turn and won't be eligible for a refunded reflex action point");
					continue;//Check next unit
				}
			}
		}
	
		if (IsReinforcementGroup)
		{
			Chance = REFLEX_ACTION_CHANCE_REINFORCEMENT;	
		}
		else if (IsYellow)
		{
			Chance = REFLEX_ACTION_CHANCE_YELLOW;
		}
		else if (IsGreen)
		{ 
			Chance = REFLEX_ACTION_CHANCE_GREEN;
		}
		//Distance Moved modifier 

		Chance += (fTileMoveRange / 2 - TilesMoved) / (fTileMoveRange); //Complicated I know, but it works
		`Log(GetFuncName() $ ": Adjusting reflex chance due to " $ TilesMoved $ " tiles moved");

		if (REFLEX_ACTION_CHANCE_REDUCTION > 0 && NumSuccessfulReflexActions > 0)
		{
			`Log(GetFuncName() $ ": Reducing reflex chance due to " $ NumSuccessfulReflexActions $ " successes");
			Chance -= NumSuccessfulReflexActions * REFLEX_ACTION_CHANCE_REDUCTION;
		}
		//check if unit is advent and if counterattack dark event is active then add modifier
		if(Member.IsAdvent() && IsDarkEvent_CounterattackActive())
		{	
			Chance += COUNTERATTACKMODIFIER;
			`Log(GetFuncName() $ ": Unit is advent and Dark Event Counter Attack is active, adding modifier");
		}
		Roll = `SYNC_FRAND();
		`Log(GetFuncName() $ ": Roll = " @ Roll @ " and chance = " @ Chance );
	
		if (Roll < Chance)
		{ 
			// Award the unit a special kind of action point for Defensive reactions. These are more restricted than standard action points.
			// See the 'DefensiveReflexAbilities' arrays in yellowalert.ini for the list
			// of abilities that have been modified to allow these action points.
			//
			// Damaged units, units in green (if enabled), or reinforcements units to defend only (if enabled)
			// get 'defensive' action points. Others get standard action points.
			
			if (Member.IsInjured() || IsGreen || (IsReinforcementGroup && bReinforcementsAlwaysDefend) || bAlwaysDefend)
			{
				Member.SetUnitFloatValue(DefensiveRefundActionUnitValue, 1, eCleanup_BeginTurn); // Set value to check for event listener ProcessRefund at ScamperEnd (Will receive a defensive action)
			}
			else
			{
				Member.ActionPoints.length = 0; // remove the default action point for scamper (Will be given two full standard actions to use at scamper end)
				Member.SetUnitFloatValue(RefundActionUnitValue, 1, eCleanup_BeginTurn); // Set value to check for event listener OnUnitTookDamage and ProcessRefund
			}
			// add one extra BT run for the refunded action point
			++NumSuccessfulReflexActions;
		}
	}
	return ELR_NoInterrupt;
}

function bool IsDarkEvent_CounterattackActive()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_DarkEvent DarkEventState;
	local int idx;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));

// Check Active Dark Events for the CounterAttack DE
	for(idx = 0; idx < AlienHQ.ActiveDarkEvents.Length; idx++)
	{
		DarkEventState = XComGameState_DarkEvent(History.GetGameStateForObjectID(AlienHQ.ActiveDarkEvents[idx].ObjectID));

		if( DarkEventState != none && DarkEventState.GetMyTemplateName() == 'DarkEvent_Counterattack')
		{
			return true;
		}
	}
	return false;
}

// Doing this here at scamper end
function EventListenerReturn ProcessRefund(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_AIGroup GroupState;
	local array<int> LivingMembers;
	local int j, NumRuns;
	local XComGameState_Unit Member;
	local X2CharacterTemplate Template;
	local string BTRoot;
	local XComGameState NewGameState;
	local UnitValue Value, OValue;
	local XComGameStateHistory History;
	local X2AIBTBehaviorTree BTMgr;
	local BTQueueEntry QEntry;
	local bool bDataChanged;

	BTMgr = `BEHAVIORTREEMGR;
	History = `XCOMHISTORY;
	GroupState = XComGameState_AIGroup( EventData );
	GroupState.GetLivingMembers(LivingMembers);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Yellow Alert Refunding actions");
	for (j = 0; j < LivingMembers.Length; ++j)
	{
		Value.fValue = 0;
		OValue.fValue = 0;
		Member = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', LivingMembers[j]));
		Member.GetUnitValue(DefensiveRefundActionUnitValue, Value);
		Member.GetUnitValue(RefundActionUnitValue, OValue);
		if ( Value.fValue == 1 || OValue.fValue == 1)
		{
			if (Value.fValue == 1)
			{
				Member.ActionPoints.AddItem(class'HelpersYellowAlert'.const.DefensiveReflexAction); //Give the unit a defensive action point
				NumRuns = 1;
				`Log("RefundActionPoint: Awarding an extra Defensive action point to unit#"$Member.ObjectID$" "$Member.GetMyTemplateName()$" Total Action points now "$ Member.ActionPoints.length);
			}
			else
			{
				Member.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);  //Refund the AI one action point to use after scamper.
				Member.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);
				NumRuns = 2;
				`Log("RefundActionPoint: Awarding an extra Offensive action point to unit#"$Member.ObjectID$" "$Member.GetMyTemplateName()$" Total Action points now "$ Member.ActionPoints.length);
			}
			bDataChanged = True;

			// Ensure that this scampering unit is in red alert (Alert causes will be added later by the game)
			// Reinforcement Units scampering in yellow will do use yellow alert data movement and run out in the open
			// This sets them to red so they use the red behavior tree
			if (Member.GetCurrentStat(eStat_AlertLevel) < 2)
				{
					Member.SetCurrentStat(eStat_AlertLevel, 2);
					`Log(GetFuncName() $ ": Setting unit# "$Member.ObjectID$" to red alert level");
				}

			Template = Member.GetMyTemplate();
			BTRoot = Template.strBehaviorTree;
			
			QEntry.Node = name(BTRoot);
			QEntry.RunCount = NumRuns;
			QEntry.ObjectID = LivingMembers[j];
			QEntry.HistoryIndex = History.GetCurrentHistoryIndex()+1;
			QEntry.bScamperEntry = false;
			QEntry.bFirstScamper = false;
			QEntry.bSurprisedScamper = false;
			QEntry.bInitFromPlayerEachRun = false;
			QEntry.bInitiatedFromEffect = false;
			
			BTMgr.ActiveBTQueue.AddItem(QEntry);
		}
	}
	if(bDataChanged)
	{
		`TACTICALRULES.SubmitGameState(NewGameState);
		BTMgr.TryUpdateBTQueue();
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}

// Used to check for units that were injured while scampering
// these units need to have their standard action point replaced with a defensive one
static function EventListenerReturn OnUnitTookDamage(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;
	local UnitValue Value;

	Unit = XComGameState_Unit(EventSource);
	
	// If Unit is injured, has been refunded a standard action point and has at least one standard action point remaining
	// And the unit doesn't already have a defensive AP, then remove one standard action point and replace with a defensive AP
	Unit.GetUnitValue(RefundActionUnitValue, Value);

 	if (Unit.IsInjured() && 
		Value.fValue == 1 && 
		Unit.ActionPoints.Find(class'X2CharacterTemplateManager'.default.StandardActionPoint) >= 0 &&
		Unit.ActionPoints.Find(class'HelpersYellowAlert'.const.DefensiveReflexAction) == -1)
	{
		`Log(GetFuncName() $ ": Replacing reflex action for injured unit# " $ Unit.ObjectID);
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Replacing reflex action for injured unit");
		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
		Unit.ActionPoints.Remove(0, 1);
		Unit.ActionPoints.AddItem(class'HelpersYellowAlert'.const.DefensiveReflexAction);
		`TACTICALRULES.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn CheckSeesAlertedAlliesAlert(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitA, UnitB;
	local int Index, AlertIndex, UnitAGroupID, UnitBGroupID;

	//Tuple.Data[0].o = UnitA;
	//Tuple.Data[1].o = UnitB;
	//Tuple.Data[2].i = AlertCause
	
	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if (Tuple.Id != 'OverrideSeesAlertedAllies')
		return ELR_NoInterrupt;

	UnitA = XComGameState_Unit(Tuple.Data[0].o);
	UnitB = XComGameState_Unit(Tuple.Data[1].o);
	UnitAGroupID = UnitA.GroupMembershipID;
	UnitBGroupID = UnitB.GroupMembershipID;

	//Check to see if this mission starts in yellow alert, for these types of missions it won't be useful to use this alert
	if( `TACTICALMISSIONMGR.ActiveMission.AliensAlerted )
	{
		//`logAI(GetFuncName() $ " Aborting! Mission starts in yellow alert");
		Tuple.Data[2].i = eAC_None;//Set the alert to none so it doesn't get recorded again
		return ELR_NoInterrupt;
	}

	//Check for Chosen, we want to skip those because they can alert the entire map
	if	(UnitB.IsChosen())
	{	
		//`logAI(GetFuncName() $ " Aborting! UnitB is: " $ UnitB.GetMyTemplate().CharacterGroupName $ " and we don't want Chosen to create these alerts");
		Tuple.Data[2].i = eAC_None;
		return ELR_NoInterrupt;
	}

	//check if units are in the same pod, we want to skip those
	if(UnitAGroupID == UnitBGroupID)
	{
		//`logAI(GetFuncName() $ " Aborting! Unit: " $ UnitA.GetMyTemplateName() $ "_" $ UnitA.ObjectID $ "is in the same group as unit: "$ UnitB.GetMyTemplateName() $ "_" $ UnitB.ObjectID);
		Tuple.Data[2].i = eAC_None;//Set the alert to none so it doesn't get recorded again
		return ELR_NoInterrupt;
	}

	// if any existing knowledge matches the incoming alert data - don't perform an update
	for( Index = 0; Index < AllyUnitsSeen.Length; ++Index )
	{
		if( AllyUnitsSeen[Index].AlertUnitID == UnitA.ObjectID && //check if this unit has alert data
			AllyUnitsSeen[Index].AlertSourceGroupID == UnitBGroupID )//check if this group has been seen by this unit
		{
			//`logAI(GetFuncName() $ " Aborting! Unit: " $ UnitA.GetMyTemplateName() $ "_" $ UnitA.ObjectID $ "has already seen Group: "$ UnitBGroupID);
			Tuple.Data[2].i = eAC_None;//Set the alert to none so it doesn't get recorded again
			return ELR_NoInterrupt;
		}
	}
	//if they make it through the two above checks then lets allow the alert to go through
	AlertIndex = AllyUnitsSeen.length;
	AllyUnitsSeen.add(1);
	AllyUnitsSeen[AlertIndex].AlertUnitID = UnitA.ObjectID;
	AllyUnitsSeen[AlertIndex].AlertSourceGroupID = UnitBGroupID;
	//`Log("Succesfully added seesalertedallies: Alerted Unit:" @UnitA.ObjectID@ "Source Group:" @UnitBGroupID);
	Tuple.Data[0].o = UnitA;
	Tuple.Data[1].o = UnitB;
	Tuple.Data[2].i = eAC_SeesAlertedAllies;
	return ELR_NoInterrupt;
}

//For debugging alert data
/*
function EventListenerReturn PrintAlertData(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local int UnitID, AlertCount, Index;
	local XComGameState_AIUnitData AIData;
	local AlertData Data;
	local vector AlertLocation;
	local XComGameStateHistory History;

	`Log(GetFuncName() $ " Printing Alert Data");
	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_AIUnitData', AIData)
	{
		UnitID = AIData.m_iUnitObjectID;
		AlertCount = AIData.GetAlertCount();
		for( Index = 0; Index < AlertCount; ++Index )
		{
			Data = AIData.GetAlertData(Index);
			AlertLocation = `XWORLD.GetPositionFromTileCoordinates(Data.AlertLocation);
			`Log(GetFuncName() $ " UnitID: "@UnitID);
			`Log(GetFuncName() $ " Index: "@Index);
			`Log(GetFuncName() $ " HistoryIndex: "@Data.HistoryIndex);
			`Log(GetFuncName() $ " PlayerTurn: "@Data.PlayerTurn);
			`Log(GetFuncName() $ " AlertCause: "@Data.AlertCause);
			`Log(GetFuncName() $ " AlertSourceUnitID: "@Data.AlertSourceUnitID);
			`Log(GetFuncName() $ " Location: "@AlertLocation);
		}
	}
	return ELR_NoInterrupt;
}
*/
// Disable the vanilla cheating behaviour of moving patrol zones to account for the
// changing line of play that comes from the XCOM squad moving around the
// map. We set the anchor point to the spawn location of the XCOM squad.
static function EventListenerReturn DisableEnemiesChasingPlayerPosition(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_BattleData BattleData;
	local XComLWTuple Tuple;
	local Vector AnchorPoint;

	Tuple = XComLWTuple(EventData);

	if (Tuple == none)
		return ELR_NoInterrupt;
	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverrideEncounterZoneAnchorPoint')
	{
		`REDSCREEN("Received unexpected event ID in DisableEnemiesChasingPlayerPosition() event handler");
		return ELR_NoInterrupt;
	}

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	AnchorPoint = BattleData.MapData.SoldierSpawnLocation;
	Tuple.Data[0].f = AnchorPoint.X;
	Tuple.Data[1].f = AnchorPoint.Y;
	Tuple.Data[2].f = AnchorPoint.Z;
	return ELR_NoInterrupt;
}

// Disable the "intercept player" AI behaviour for all missions by setting a new
// WOTC property on the battle data object. This can probably still be overridden
// by Kismet, but I'm not sure why we would ever want to do that.
static function EventListenerReturn DisableInterceptAIBehavior(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local bool SubmitGameState;

	SubmitGameState = false;
	History = `XCOMHISTORY;
	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Force Disable Intercept Movement");
		SubmitGameState = true;
	}
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	BattleData.bKismetDisabledInterceptMovement = true;
	if (SubmitGameState)
	{
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}

// Override AI intercept/patrol behavior. The base game uses a function to control pod movement.
//
// For the overhaul mod we will not use either upthrottling or the 'intercept' behavior if XCOM passes
// the pod along the LoP. Instead we will use the pod manager to control movement. But we still want pods
// with no jobs to patrol as normal.
static function EventListenerReturn DisableDefaultPatrolBehavior(Object EventData, Object EventSource,  XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_AIGroup Group;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverridePatrolBehavior')
	{
		`REDSCREEN("Received unexpected event ID in DisableDefaultPatrolBehavior() event handler");
		return ELR_NoInterrupt;
	}

	Group = XComGameState_AIGroup(EventSource);

	if (Group != none && `LWPODMGR.PodHasJob(Group) || `LWPODMGR.GroupIsInYellowAlert(Group))
	{
		// This pod has a job, or is in yellow alert. Don't let the base game alter its alert.
		// For pods with jobs, we want the game to use the alert that we have set for them.
		// For yellow alert pods, either they have a job, in which case they should go where that job
		// says they should, or they should be investigating their yellow alert cause.
		Tuple.Data[0].b = true;
	}
	else
	{
		// No job. Let the base game patrol, but don't try to use the intercept mechanic.
		Tuple.Data[0].b = false;
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnTacticalBeginPlay(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameStateHistory History;
	local Object ThisObj;

	History = `XCOMHISTORY;

	// Hack for tactical quick launch: Set up our pod manager & reinforcements. This is usually done by DLCInfo.OnPreMission, which is not
	// called for TQL.
	SetUpForTQL(History);

	ThisObj = self;
	`XEVENTMGR.UnRegisterFromEvent(ThisObj, EventID);
	return ELR_NoInterrupt;
}

function SetUpForTQL(XComGameStateHistory History)
{
	local XComGameState_BattleData BattleData;
	local XComGameState_LWPodManager PodManager;
	//local XComGameState_LWReinforcements Reinforcements;
	local XComGameState NewGameState;
	
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData.bIsTacticalQuickLaunch)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Create Pod Manager for TQL");
		PodManager = XComGameState_LWPodManager(NewGameState.CreateStateObject(class'XComGameState_LWPodManager'));
		NewGameState.AddStateObject(PodManager);
		PodManager.OnBeginTacticalPlay(NewGameState);
		//Reinforcements = XComGameState_LWReinforcements(NewGameState.CreateStateObject(class'XComGameState_LWReinforcements'));
		//NewGameState.AddStateObject(Reinforcements);
		//Reinforcements.Reset();
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
}

// If we have a 'RedAlert' or 'YellowAlert' ability activation set the alert flag in the pod manager: we're on.
static function EventListenerReturn SetPodManagerAlert(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Ability Ability;
	local XComGameState NewGameState;
	local XComGameState_LWPodManager NewPodManager;

	// If we're in alert level red we no longer care about activated abilities
	if (`LWPODMGR.AlertLevel == `ALERT_LEVEL_RED)
	{
		return ELR_NoInterrupt;
	}

	Ability = XComGameState_Ability(EventData);
	if (Ability != none && 
			(Ability.GetMyTemplateName() == 'RedAlert' || Ability.GetMyTemplateName() == 'YellowAlert') &&
			GameState != none && 
			XComGameStateContext_Ability(GameState.GetContext()).ResultContext.InterruptionStep <= 0)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("PodManager: RedAlert");
		NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', `LWPODMGR.ObjectID));
		NewPodManager.AlertLevel = (Ability.GetMyTemplateName() == 'RedAlert') ? `ALERT_LEVEL_RED : `ALERT_LEVEL_YELLOW;
		`TACTICALRULES.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

//Filter down to alien or xcom turn begin
static function EventListenerReturn LW2OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local XComGameState_Player PlayerState;

	PlayerState = XComGameState_Player (EventData);
	if (PlayerState == none)
	{
		`LOG ("LW2OnPlayerTurnBegun: PlayerState Not Found");
		return ELR_NoInterrupt;
	}

	if(PlayerState.GetTeam() == eTeam_XCom)
	{
		`XEVENTMGR.TriggerEvent('XComTurnBegun', PlayerState, PlayerState);
	}
	if(PlayerSTate.GetTeam() == eTeam_Alien)
	{
		`XEVENTMGR.TriggerEvent('AlienTurnBegun', PlayerState, PlayerState);
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnAlienTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_LWPodManager NewPodManager;
//	local XComGameState_Player XComPlayer;

	// If we're still concealed, don't take any actions yet.
	//XComPlayer = class'HelpersYellowAlert'.static.FindPlayer(eTeam_XCom);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Preparing Pod Jobs");
    NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', `LWPODMGR.ObjectID));

	// If we're in green alert (from mission start) check if we should immediately bump it to yellow
	// because of the mission type.
	if (NewPodManager.AlertLevel == `ALERT_LEVEL_GREEN && `TACTICALMISSIONMGR.ActiveMission.AliensAlerted)
	{
		NewPodManager.AlertLevel = `ALERT_LEVEL_YELLOW;
	}

	// Don't activate pod mechanics until both we have an alert activation on a pod
    // And Xcom hasn't broken concealment, Pods may activate now due to lost, third parties, the reaper
	// We them to investigate alerts until they know Xcom is there, at that time they will use the pod jobs
	// Removed the check for Xcom breaking concealment 08/26/21
	if (NewPodManager.AlertLevel != `ALERT_LEVEL_GREEN) //&& !XComPlayer.bSquadIsConcealed)
	{
        NewPodManager.TurnInit(NewGameState);
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnUnitGroupTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState NewGameState;
    local XComGameState_LWPodManager NewPodManager;
    local XComGameState_AIGroup GroupState;
    
    GroupState = XComGameState_AIGroup(EventSource);
    if (GroupState == none)
    {
        `REDSCREEN("XCGS_AIGroup not passed as event source for 'UnitGroupTurnBegun'");
        return ELR_NoInterrupt;
    }
	//Only want to update alien team pods
	if (GroupState.TeamName != ETeam_Alien)
	{
		return ELR_NoInterrupt;
	}
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Pod Job");
	NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', `LWPODMGR.ObjectID));
	NewPodManager.UpdatePod(NewGameState, GroupState);

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

// Record turn that objective is completed for pod job manager
// Upgrade any green alert units to yellow
function EventListenerReturn OnObjectiveComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_BattleData BattleData;
	local XComGameState NewGameState;
	local XComGameState_LWPodManager PodManager, NewPodManager;
	local int TurnCount;

	BattleData = XComGameState_BattleData(EventData);
	PodManager = `LWPODMGR;
	//If objective is complete and has not been recorded yet, record turn objective complete
	if( PodManager.ObjectiveCompleteTurn < 0 && BattleData.AllStrategyObjectivesCompleted() )
	{
		TurnCount = class'HelpersYellowAlert'.static.FindPlayer(eTeam_Alien).PlayerTurnCount;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Objective Complete Turn");
		NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', PodManager.ObjectID));
		NewPodManager.ObjectiveCompleteTurn = TurnCount;

		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`TACTICALRULES.SubmitGameState(NewGameState);
			`log("Objective Complete Turn: "$ TurnCount);
			AISetAllToYellowAlert();
		}
		else
		{
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		}

	}
	return ELR_NoInterrupt;
}

function AISetAllToYellowAlert()
{
	local XGAIPlayer kAI;
	local array<XComGameState_Unit> Units;
	local XComGameState_Unit Unit;
	local array<int> UnitIDs; 

	kAI = XGAIPlayer(`BATTLE.GetAIPlayer());
	kAI.GetPlayableUnits(Units);
	// Only set units in green alert to yellow alert
	foreach Units(Unit)
	{
		if(Unit.GetCurrentStat(eStat_AlertLevel) == 0)
		{
			UnitIDs.additem(Unit.ObjectID);
		}
	}
	kAI.ForceAbility(UnitIDs, 'YellowAlert');
}

// This event is added by Kismet when the VIP is rescued, Blacksite vial taken, etc. to Record turn that objective is completed for pod job manager
// The OnObjectiveComplete listener doesn't always pickup key situations when the alarm should be triggered
// Upgrade any green alert units to yellow
function EventListenerReturn OnPodJobConverge(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;
	local XComGameState_LWPodManager PodManager, NewPodManager;
	local int TurnCount;

	PodManager = `LWPODMGR;
	//If objective complete has not been recorded yet, record turn objective complete
	if( PodManager.ObjectiveCompleteTurn < 0 )
	{
		TurnCount = class'HelpersYellowAlert'.static.FindPlayer(eTeam_Alien).PlayerTurnCount;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Objective Complete Turn");
		NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', PodManager.ObjectID));
		NewPodManager.ObjectiveCompleteTurn = TurnCount;

		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`TACTICALRULES.SubmitGameState(NewGameState);
			`log("Objective Complete Turn: "$ TurnCount);
			AISetAllToYellowAlert();
		}
		else
		{
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		}
	}
	return ELR_NoInterrupt;
}

//Used by the pod manager to track when alien units spot the evac zone
function EventListenerReturn CheckEvacZoneAlert(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_EvacZone EvacZone;
	local XComGameState_Unit MovedUnit;
	local XComGameState_Player MovedUnitPlayer;
	local XComGameStateHistory History;
	local int i, PathIndex, SightRadiusUnitsSq;
	local XComGameStateContext_Ability MoveContext;
	local XComGameState OtherGameState, NewGameState;
	local TTile TestTile, BlankTile;
	local bool EvacZoneSpotted, bIsInSightRadius;
	local GameRulesCache_VisibilityInfo OutVisInfo;
	local XComGameState_LWPodManager PodManager, NewPodManager;

	`BEHAVIORTREEMGR.bWaitingOnEndMoveEvent = false;

	History = `XCOMHISTORY;
	MovedUnit = XComGameState_Unit(EventData);
	MovedUnitPlayer = XComGameState_Player(History.GetGameStateForObjectID(MovedUnit.ControllingPlayer.ObjectID));
	//Looking for alien units only
	if( MovedUnitPlayer.TeamFlag != eTeam_Alien )
	{
		return ELR_NoInterrupt;
	}

	PodManager = `LWPODMGR;
	EvacZone = class'XComGameState_EvacZone'.static.GetEvacZone(eTeam_XCom);
	//If the evac zone was already spotted and the aliens have eyes on that location, check to see if the evac zone is no longer there
	if(PodManager.EvacZoneSpotted)
	{
		if (class'X2TacticalVisibilityHelpers'.static.CanUnitSeeLocation(MovedUnit.ObjectID, PodManager.EvacZoneLocation))
		{
			//If evac zone is no longer where it used to be let's reset the stored pod manager variables
			if (PodManager.EvacZoneLocation != EvacZone.CenterLocation || EvacZone == None) 
			{	
				OtherGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(" Yellow Alert Pod Manager Clearing location of Evac Zone.");
				NewPodManager = XComGameState_LWPodManager(OtherGameState.ModifyStateObject(class'XComGameState_LWPodManager', PodManager.ObjectID));
				NewPodManager.EvacZoneSpotted = false;
				NewPodManager.EvacZoneLocation = BlankTile;
				`TACTICALRULES.SubmitGameState(OtherGameState);
				`Log(GetFuncName()@"Clearing location of Evac Zone.");
			}
		}
	}
	//No Evac zone active, no need to check further for visuals on Evac Zone
	if( EvacZone == None )
	{
		//`Log(GetFuncName()@"failed - No Evac Zone found.");
		return ELR_NoInterrupt;
	}

	//Begin checks for an existing evac zone
	EvacZoneSpotted = false;	
	if (class'X2TacticalVisibilityHelpers'.static.CanUnitSeeLocation(MovedUnit.ObjectID, EvacZone.CenterLocation))
	{
		EvacZoneSpotted = true;
	}
	else 
	{
		 //The Evac Zone is not visible to the this unit's current location
		 //Process the moved unit's path backwards to see if we can spot the evac zone during the move
		MoveContext = XComGameStateContext_Ability(GameState.GetContext());
		if( (MoveContext != None) && (MoveContext.GetMovePathIndex(MovedUnit.ObjectID) >= 0)) 
		{
			PathIndex = MoveContext.GetMovePathIndex(MovedUnit.ObjectID);

			i = (MoveContext.InputContext.MovementPaths[PathIndex].MovementTiles.Length - 1);
			while( i >= 0 )
			{
				TestTile = MoveContext.InputContext.MovementPaths[PathIndex].MovementTiles[i];
				`XWORLD.CanSeeTileToTile(EvacZone.CenterLocation, TestTile, OutVisInfo);

				SightRadiusUnitsSq = `METERSTOUNITS(MovedUnit.GetVisibilityRadius());
				SightRadiusUnitsSq = SightRadiusUnitsSq * SightRadiusUnitsSq;
				bIsInSightRadius = SightRadiusUnitsSq >= OutVisInfo.DefaultTargetDist;

				if( bIsInSightRadius )
				{
					EvacZoneSpotted = true;
					i = INDEX_NONE;
				}

				--i;
			}
		}
	}
	// If the moved unit has or can see the Evac Zone, then we need to check if the existing evac zone has been seen
	// before updating the Pod Manager Variables for tracking Evac Zone
	if (EvacZoneSpotted)
	{
		if (PodManager.EvacZoneSpotted && PodManager.EvacZoneLocation == EvacZone.CenterLocation)
		{
			//`Log(GetFuncName()@"existing data found at this location - aborting");
			return ELR_NoInterrupt;
		}

		// Update Pod Manager Variables for tracking Evac Zone
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(" Yellow Alert Pod Manager updating location of Evac Zone.");
		NewPodManager = XComGameState_LWPodManager(NewGameState.ModifyStateObject(class'XComGameState_LWPodManager', PodManager.ObjectID));
		NewPodManager.EvacZoneSpotted = true;
		`Log(GetFuncName()@"Updating location of Evac Zone.");
		NewPodManager.EvacZoneLocation = EvacZone.CenterLocation;
		if(NewGameState.GetNumGameStateObjects() > 0)
		{
			`TACTICALRULES.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}
	else
	{
		//`Log(GetFuncName()@"Alien unit moved and did not see Evac Zone.");
	}
	return ELR_NoInterrupt;
}

static function EventListenerReturn OnOverrideAllowedAlertCause(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverrideAllowedAlertCause')
	{
		`REDSCREEN("Received unexpected event ID in OnOverrideAllowedAlertCause() event handler");
		return ELR_NoInterrupt;
	}
	// Allow all causes
	Tuple.Data[1].b = true;

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnOverrideEnemyFactionsAlertsOutsideVision(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local EAlertCause AlertCause;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverrideEnemyFactionsAlertsOutsideVision')
	{
		`REDSCREEN("Received unexpected event ID in OnOverrideEnemyFactionsAlertsOutsideVision() event handler");
		return ELR_NoInterrupt;
	}
	Tuple.Data[1].b = false;
	AlertCause = EAlertCause(Tuple.Data[0].i);
	switch( AlertCause )
	{
		case eAC_MapwideAlert_Hostile:
		case eAC_MapwideAlert_Peaceful:
		case eAC_AlertedByCommLink:
		case eAC_TakingFire:
		case eAC_TookDamage:
		case eAC_DetectedNewCorpse://added
		case eAC_DetectedAllyTakingDamage:
		case eAC_DetectedSound://added
		case eAC_AlertedByYell:
		case eAC_SeesExplosion://added and now working thanks to this mod
		case eAC_SeesSmoke://used for Evac Zone Spotted alerts
		case eAC_SeesFire://not used but added anyway
		case eAC_SeesAlertedAllies://THis is now working properly thanks to the community highlander update so I could change some code.  
								   //These type of alerts are dynamic and use the alerted allies current location, and not the original location when see.
			Tuple.Data[1].b = true;
		break;
		case eAC_SeesSpottedUnit://activate pods outside of Xcom's vision when they see each other
			if(class'HelpersYellowAlert'.static.AISeesAIEnabled())
			{
				Tuple.Data[1].b = true;
				break;
			}
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnOverridePatrolDestination(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local EAlertCause AlertCause;

	Tuple = XComLWTuple(EventData);
	
	if (Tuple == none)
		return ELR_NoInterrupt;
	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverridePatrolDestination')
	{
		`REDSCREEN("Received unexpected event ID in OnOverridePatrolDestination() event handler");
		return ELR_NoInterrupt;
	}
	AlertCause = EAlertCause(Tuple.Data[0].i);
	if(AlertCause == eAC_UNUSED_3) //Alerts set by the pod job manager
	{
		Tuple.Data[1].b = true;
	}
	return ELR_NoInterrupt;
}

static function EventListenerReturn ShouldCivilianRunFromOtherUnit(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit OtherUnitState;
	local bool DoesAIAttackCivilians;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'ShouldCivilianRun')
	{
		`REDSCREEN("Received unexpected event ID in ShouldCivilianRunFromOtherUnit() event handler");
		return ELR_NoInterrupt;
	}

	OtherUnitState = XComGameState_Unit(Tuple.Data[0].o);
	DoesAIAttackCivilians = Tuple.Data[1].b;

	// Civilians shouldn't run from the aliens/ADVENT unless Team Alien
	// is attacking neutrals.
	Tuple.Data[2].b = !(!DoesAIAttackCivilians && OtherUnitState.GetTeam() == eTeam_Alien); 

	return ELR_NoInterrupt;
}

defaultProperties
{
    ScreenClass = UITacticalHUD
}

