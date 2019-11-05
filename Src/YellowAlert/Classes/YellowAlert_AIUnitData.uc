Class YellowAlert_AIUnitData extends XComGameState_AIUnitData;

function array<XComGameState_Player> GetEnemyPlayers( XGPlayer AIPlayer)
{
	local array<XComGameState_Player> EnemyPlayers;
	local XComGameState_Player PlayerStateObject, EnemyStateObject, StateObject;

	if (AIPlayer == none)
		return EnemyPlayers;

	PlayerStateObject = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(AIPlayer.ObjectID));

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', StateObject)
	{
		if (StateObject.ObjectID == PlayerStateObject.ObjectID)
			continue;
		//Ignore lost and civilians, this check is for purposes of determining enemies with guns
		if (StateObject.GetTeam() == ETeam_TheLost || StateObject.GetTeam() == ETeam_Neutral)
			continue;
		EnemyStateObject = StateObject;
		if (PlayerStateObject.IsEnemyPlayer(EnemyStateObject))

		if (EnemyStateObject != none)
		{
			EnemyPlayers.AddItem(EnemyStateObject);
		}	
	}
	return EnemyPlayers;
}

function GetAbsoluteKnowledgeUnitList( out array<StateObjectReference> arrKnownUnits, optional out array<XComGameState_Unit> UnitStateList, bool bSkipUndamageable=true, bool IncludeCiviliansOnTerror=true)
{
	local AlertData kData;
	local StateObjectReference kUnitRef;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComGameState_BattleData Battle;
	local XGAIPlayer AIPlayer, EnemyAIPlayer;
	local XGPlayer EnemyPlayer;
	local XComGameState_Player EnemyPlayerState;
	local array<XComGameState_Player> EnemyPlayers;
	local array<XComGameState_Unit> AllEnemies;

	History = `XCOMHISTORY;
	Unit = XComGameState_Unit(History.GetGameStateForObjectID(m_iUnitObjectID));
	AIPlayer = XGAIPlayer(History.GetVisualizer(Unit.ControllingPlayer.ObjectID));

	if( AIPlayer != None && AIPlayer.bAIHasKnowledgeOfAllUnconcealedXCom )
	{
		EnemyPlayers = GetEnemyPlayers(AIPlayer);
		foreach EnemyPlayers(EnemyPlayerState)
		{
			if (EnemyPlayerState.GetTeam() == ETeam_XCom)
			{
				EnemyPlayer = XGPlayer(EnemyPlayerState.GetVisualizer());
			
				if( bSkipUndamageable )
				{
					EnemyPlayer.GetPlayableUnits(AllEnemies);
				}
				else
				{
					EnemyPlayer.GetUnits(AllEnemies);
				}
			}
			else
			{
				EnemyAIPlayer = XGAIPlayer(EnemyPlayerState.GetVisualizer());
		
				if( bSkipUndamageable )
				{
					EnemyAIPlayer.GetPlayableUnits(AllEnemies);
				}
				else
				{
					EnemyAIPlayer.GetUnits(AllEnemies);
				}
			}
		}
		UnitStateList.Length = 0;
		arrKnownUnits.Length = 0;
		foreach AllEnemies(Unit)
		{
			if( !Unit.IsConcealed() && !Unit.bRemovedFromPlay )
			{
				arrKnownUnits.AddItem(Unit.GetReference());
				UnitStateList.AddItem(Unit);
			}
		}
	}
	//bAIHasKnowledgeOfAllUnconcealedXCom defaults to true and is unused so this section wont ever apply
	else
	{
		arrKnownUnits.Length = 0;
		foreach m_arrAlertData(kData)
		{
			if( IsCauseAbsoluteKnowledge(kData.AlertCause) )
			{
				Unit = XComGameState_Unit(History.GetGameStateForObjectID(kData.AlertSourceUnitID));
				if( bSkipUndamageable &&
				   (Unit.bRemovedFromPlay
				   || Unit.IsDead()
				   || Unit.IsIncapacitated()
				   || Unit.bDisabled
				   || Unit.GetMyTemplate().bIsCosmetic)
				   )
				{
					continue;
				}

				kUnitRef = Unit.GetReference();
				if( arrKnownUnits.Find('ObjectID', kUnitRef.ObjectID) == -1 )
				{
					arrKnownUnits.AddItem(kUnitRef);
					UnitStateList.AddItem(Unit);
				}
			}
		}
	}

	if( IncludeCiviliansOnTerror )
	{
		// Include civilians on terror maps.  These don't have alert data.
		Battle = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		if( Battle.AreCiviliansAlienTargets() )
		{
			class'X2TacticalVisibilityHelpers'.static.GetAllVisibleUnitsOnTeamForSource(m_iUnitObjectID, eTeam_Neutral, arrKnownUnits);
		}
	}
}

//Changed the causes to allow unseen units to be given yellow alert
static function bool IsCauseAllowedForNonvisibleUnits(EAlertCause AlertCause)
{
	return true;
}

// these alert causes are allowed to change alert levels to yellow or red even if they occur outside the player's vision (offscreen) and are triggered by other AIs
static function bool ShouldEnemyFactionsTriggerAlertsOutsidePlayerVision(EAlertCause AlertCause)
{
	local bool bResult;

	bResult = false;
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
		bResult = true;
		break;
	case eAC_SeesSpottedUnit://activate pods outside of Xcom's vision when they see each other
		if(class'HelpersYellowAlert'.static.AISeesAIEnabled())
		{
			bResult = true;
			break;
		}
	}
	return bResult;
}