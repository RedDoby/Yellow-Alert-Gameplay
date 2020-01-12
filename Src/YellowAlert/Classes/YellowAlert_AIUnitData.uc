Class YellowAlert_AIUnitData extends XComGameState_AIUnitData;

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