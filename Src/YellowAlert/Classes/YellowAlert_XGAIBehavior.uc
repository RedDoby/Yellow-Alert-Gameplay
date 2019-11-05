// This is an Unreal Script
class YellowAlert_XGAIBehavior extends XGAIBehavior;

//Need to add ETeam one and two to possible enemies
function UpdateSightRange()
{
    local array<XComGameState_Unit> XComList;
    local XComGameState_Unit EnemyState;
    local float VisRadius;
    VisRadius = UnitState.GetVisibilityRadius();
    m_fSightRangeSq = Square(`METERSTOUNITS(VisRadius+3));// Added 3m sight range buffer.

    bSameVisibilityRangeAsEnemies = true;
    if ( UnitState.GetTeam() == eTeam_Alien )
    {
        GetAllKnownEnemyStates(XComList);
        foreach XComList(EnemyState)
        {
            if( (EnemyState.GetTeam() == eTeam_XCom || EnemyState.GetTeam() == eTeam_Resistance || 
			EnemyState.GetTeam() == eTeam_One || EnemyState.GetTeam() == eTeam_Two) && 
			VisRadius != EnemyState.GetVisibilityRadius() )
            {
                bSameVisibilityRangeAsEnemies = false;
                break;
            }
        }
    }
}

//A small fix that I thought everyone would appreciate since we have raider factions and resistance now. This fixes the check for flanking.
function bool HasKnowledgeOfXCom()
{
	local array<XComGameState_Unit> KnownEnemies;
	local XComGameState_Unit EnemyState;
	GetAllKnownEnemyStates(KnownEnemies);
	foreach KnownEnemies(EnemyState)
	{
		if (EnemyState.GetTeam() != eTeam_TheLost || EnemyState.GetTeam() != eTeam_Neutral)
		{
			return true;
		}
	}
	return false;
}

//AlertRadius for sound was not implemented (SoundRange info isn't put into alert data). Use alert cause instead.
function bool BT_AlertDataWasSoundMade()
{
	local AlertData Data;
	if( GetAlertData(Data) )
	{
		return (Data.AlertCause == eAC_DetectedSound);
	}
	return false;
}

// Determine what kind of move should happen.
simulated function ExecuteMoveAbility()
{
	local string strFail;
	local bool bMindControlled;
	//local int nEnemiesVisible;
	local int InitialAlertLevel;

	if( !UnitState.ControllingPlayerIsAI() )
	{
		`LogAI("XComMovement.");
		GotoState('XComMovement');
		return;
	}

	bMindControlled = class'XGAIPlayer'.static.IsMindControlled(UnitState);
	
	//nEnemiesVisible = UnitState.GetNumVisibleEnemyUnits(true,true);//class'X2TacticalVisibilityHelpers'.static.GetNumVisibleEnemyTargetsToSource(m_kUnit.ObjectID);
	//
	// update - these should be completely based on the visualizers alert state.
	InitialAlertLevel = GetAlertLevelOverride(); // May be overridden by initial patrol group alert level.
	 
	//Removes the unrevealed check so that yellow alert movement can process
	if( InitialAlertLevel == 0 && m_kPlayer != None && !m_kPlayer.IsScampering(UnitState.ObjectID) && !bMindControlled && !bDisableGreenAlertMovement ) //Green alert level. For green alert movement.
	{
		`LogAI("GreenAlertMovement.");
		GotoState('GreenAlertMovement');
	}
	else if( m_iAlertDataScoreHighestIndex != INDEX_NONE && m_bAlertDataMovementDestinationSet )
	{
		`LogAI("GroupAlertDataMovement.");//Use Group Movement for Alert Data
		GotoState('GroupAlertDataMovement');
	}
	else if( InitialAlertLevel == 2 || bMindControlled || m_kPlayer.IsScampering(UnitState.ObjectID)) // Red alert level.
	{
		`LogAI("RedAlertMovement.");
		GotoState('RedAlertMovement');
	}
	else if ( InitialAlertLevel == 1 ) // Yellow alert
	{
		if (HasAlertLocation(,true))
		{
			`LogAI("OrangeAlertMovement.");
			GotoState('OrangeAlertMovement');
		}
		else
		{
			`LogAI("GroupYellowAlertMovement.");
			GotoState('GroupYellowAlertMovement');
		}
	}
	
	else
	{
		if( bDisableGreenAlertMovement && (m_iAlertDataScoreHighestIndex == INDEX_NONE || !m_bAlertDataMovementDestinationSet))
		{
			`RedScreenOnce(" Green Alert Movement was disabled without having any Alert Data Movement destination set!  @acheng @jbrawley");
		}
		`LogAI("NON-MOVE.");
		strFail @= "ExecuteMoveAbility:No move state valid!";
		SwitchToAttack(strFail);
	}
}

state GroupAlertDataMovement extends AlertDataMovement
{
    // LWS Mods: Alert move should move in a group if unactivated (implies EnableYellowAlert is
    // true since otherwise all unactivated AI uses Green movement).
    function bool IsGroupMove()
	{
		if (UnitState.IsUnrevealedAI() && m_kPatrolGroup != None && !m_kPatrolGroup.bDisableGroupMove)
		{
			return true;
		}
		return super.IsGroupMove();
	}
}

state GroupYellowAlertMovement extends YellowAlertMovement
{
    // LWS Mods: Yellow Alert move should move in a group if unactivated (implies EnableYellowAlert is
    // true since otherwise all unactivated AI uses Green movement).
    function bool IsGroupMove()
	{
		if (UnitState.IsUnrevealedAI() && m_kPatrolGroup != None && !m_kPatrolGroup.bDisableGroupMove)
		{
			return true;
		}
		return super.IsGroupMove();
	}
}

//for debugging alert data

function BT_UpdateBestAlertData()
{	
	local AlertData Data;

	`LogAIBT(DebugBTScratchText);
	`Log("- - -  Total Score = "@m_iAlertDataScoreCurrent);
	GetAlertData(Data);

	`Log("UnitID: "$m_kUnit.ObjectID);
	`Log("HistoryIndex: "@Data.HistoryIndex);
	`Log("AlertKnowledgeType: "@Data.AlertKnowledgeType);
	`Log("PlayerTurn: "@Data.PlayerTurn);
	`Log("AlertLocation X: "@Data.AlertLocation.X@" Y: "@Data.AlertLocation.Y);
	`Log("AlertCause: "@Data.AlertCause);
	`Log("AlertSourceUnitID: "@Data.AlertSourceUnitID);
	`Log("KismetTag: "@Data.KismetTag);
	`Log("bWasAggressive: "@Data.bWasAggressive);

	if( m_iAlertDataScoreCurrent > m_iAlertDataScoreHighest )
	{
		m_iAlertDataScoreHighestIndex = m_iAlertDataIter;
		m_iAlertDataScoreHighest = m_iAlertDataScoreCurrent;
	}
	if( m_iAlertDataScoreHighest >= 0 )
	{
		`Log("  -- Best: Alert: Alert Data Index# "$m_iAlertDataScoreHighestIndex@" ("$m_iAlertDataScoreHighest$")\n");
	}
	else
	{
		`Log("  -- Best: Unit: NONE\n");
	}
}

// Force unit to end its turn, used for non-active units, and for major failures in AI ability selection.
simulated function SkipTurn( optional string DebugLogText="" )
{
	local XComGameStateContext_TacticalGameRule EndTurnContext;

	`logAI("XGAIBehavior::SkipTurn::"$m_kUnit @ self@m_kUnit.ObjectID@ DebugLogText);

	RefreshUnitCache();
	if (UnitState.NumAllActionPoints() != 0)
	{
		// If unrevealed, the entire group skips its turn.  Fixes assert with group movement, after group leader skips its move.

		// LWS Mods: This breaks reflex actions: A unit that is killed during scamper will skip its turn (no actions to take!)
		// which will force the entire pod to skip any bonus reflex action (in addition to scamper, which is handled separately).
		// I haven't seen this group movement assert, although making this change makes me pretty nervous. Hopefully this would
		// only assert if the unit skips its turn for some reason while it's still unrevealed, so if it's now revealed let the
		// group continue their turn.
		if( StartedTurnUnrevealed() && UnitState.IsUnrevealedAI() )
		{
			SkipGroupTurn();
		}
		else
		{
			EndTurnContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
			EndTurnContext.GameRuleType = eGameRule_SkipUnit;
			EndTurnContext.UnitRef = `XCOMHISTORY.GetGameStateForObjectID(m_kUnit.ObjectID).GetReference();
			`XCOMGAME.GameRuleset.SubmitGameStateContext(EndTurnContext);
			`CHEATMGR.AIStringsUpdateString(m_kUnit.ObjectID, "SkippedTurn.");
		}
	}
	if (m_kPlayer != None)
	{
		m_kPlayer.InvalidateUnitToMove(m_kUnit.ObjectID);
	}
}

// Force AI traversals to be saved.
function SaveBTTraversals()
{
	local int RootIndex;
	local array<BTDetailedInfo> arrStatusList;

	BT_GetNodeDetailList(arrStatusList);
	RootIndex = `BEHAVIORTREEMGR.GetNodeIndex(m_kBehaviorTree.m_strName);
	AddTraversalData(arrStatusList, RootIndex);
}