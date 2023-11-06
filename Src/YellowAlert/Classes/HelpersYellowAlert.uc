// This is an Unreal Script
class HelpersYellowAlert extends object Config(YellowAlert);

var config const bool EnableAItoAISeesUnitActivation;
var config array<name> ExcludedMissionNames;

const OffensiveReflexAction = 'OffensiveReflexActionPoint_LW';
const DefensiveReflexAction = 'DefensiveReflexActionPoint_LW';

// Copied from XComGameState_Unit::GetEnemiesInRange, except will retrieve all units on the alien team within
// the specified range. No longer needed, will be added to highlander
static function GetUnitsInRange(TTile kLocation, int nMeters, out array<StateObjectReference> OutEnemies)
{
	local vector vCenter, vLoc;
	local float fDistSq;
	local XComGameState_Unit kUnit;
	local XComGameStateHistory History;
	local eTeam Team;
	local float AudioDistanceRadius, UnitHearingRadius, RadiiSumSquared;

	History = `XCOMHISTORY;
	vCenter = `XWORLD.GetPositionFromTileCoordinates(kLocation);
	AudioDistanceRadius = `METERSTOUNITS(nMeters);
	fDistSq = Square(AudioDistanceRadius);

	foreach History.IterateByClassType(class'XComGameState_Unit', kUnit)
	{
		Team = kUnit.GetTeam();
		if( Team != eTeam_Xcom && Team != eTeam_Neutral && kUnit.IsAlive() )
		{
			vLoc = `XWORLD.GetPositionFromTileCoordinates(kUnit.TileLocation);
			UnitHearingRadius = kUnit.GetCurrentStat(eStat_HearingRadius);

			RadiiSumSquared = fDistSq;
			if( UnitHearingRadius != 0 )
			{
				RadiiSumSquared = Square(AudioDistanceRadius + UnitHearingRadius);
			}

			if( VSizeSq(vLoc - vCenter) < RadiiSumSquared )
			{
				OutEnemies.AddItem(kUnit.GetReference());
			}
		}
	}
}

//optional config if true then AI can activate other AI on sight
static function bool AISeesAIEnabled()
{
	local name ExcludedMissionName, MissionName;
	
	if(!default.EnableAItoAISeesUnitActivation)
	{
		return false;
	}

	MissionName = CurrentMissionName(); 
	//Look for excluded mission Names
	foreach Default.ExcludedMissionNames(ExcludedMissionName)
	{
		if (MissionName == ExcludedMissionName)
		{
			//`Log("Yellow alert "$ExcludedMissionName$" Mission Name Excluded from AI Sight Activations");
			return false;
		}
	}	

    return default.EnableAItoAISeesUnitActivation;
}

function static Name CurrentMissionName()
{
    local XComGameState_BattleData BattleData;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	return BattleData.MapData.ActiveMission.MissionName;
}

function static string CurrentMissionFamily()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.MissionFamily == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].MissionFamily;
    }

    return GeneratedMission.Mission.MissionFamily;
}

function static XComGameState_Player FindPlayer(ETeam team)
{
    local XComGameState_Player PlayerState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', PlayerState)
    {
        if(PlayerState.GetTeam() == team)
        {
            return PlayerState;
        }
    }

    return none;
}