Class YellowAlert_XGAIPatrolGroup extends XGAIPatrolGroup;

// Attempt to override the current patrol path with any Throttling Beacons or Mapwide Alert locations.
//Yellow Alert Gameplay - addeed Unused_3 as the default alerts assigned by the job manager
function bool CheckForOverrideDestination(out vector CurrDestination, int ObjectID)
{
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
	local XComGameState_AIUnitData AIData;
	local int AIDataID;
	local AlertData AlertData;
	History = `XCOMHISTORY;
	Unit = XComGameState_Unit(History.GetGameStateForObjectID(ObjectID));
	AIDataID = Unit.GetAIUnitDataID();
	if( AIDataID > 0 )
	{
		AIData = XComGameState_AIUnitData(History.GetGameStateForObjectID(AIDataID));
		if( AIData.GetPriorityAlertData(AlertData) )
		{
			if( AlertData.AlertCause == eAC_ThrottlingBeacon ||
				AlertData.AlertCause == eAC_MapwideAlert_Hostile ||
				AlertData.AlertCause == eAC_MapwideAlert_Peaceful ||
				AlertData.AlertCause == eAC_UNUSED_3)//Alerts set by the pod job manager
				
			{
				CurrDestination = `XWORLD.GetPositionFromTileCoordinates(AlertData.AlertLocation);
				return true;
			}
		}
	}
	return false;
}