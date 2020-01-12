//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodJob_MoveToLocation.uc
//  AUTHOR:  RedDobe
//  PURPOSE: A pod job to move to a allow pods to scout the map.
//---------------------------------------------------------------------------------------
class XComGameState_LWPodJob_Scout extends XComGameState_LWPodJob config(LW_PodManager);

function InitJob(LWPodJobTemplate JobTemplate, XComGameState_AIGroup Group, int JobID, EAlertCause Cause, String Tag, XComGameState NewGameState)
{
	RemoveAllAlertsFromGroup(Group, NewGameState);
    super.InitJob(JobTemplate, Group, JobID, Cause, Tag, NewGameState);
}

// Remove all alerts from all members of this group.
function RemoveAllAlertsFromGroup(XComGameState_AIGroup Group, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_AIUnitData AIUnitData;
	local int AIUnitDataID;
	local XComGameState_Unit Unit;
	local array<int> LivingMembers;
	local int UnitIdx;

	History = `XCOMHISTORY;
	Group.GetLivingMembers(LivingMembers);
	
	for (UnitIdx = 0; UnitIdx < LivingMembers.Length; ++UnitIdx)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(LivingMembers[UnitIdx]));
		AIUnitDataID = Unit.GetAIUnitDataID();
		if (AIUnitDataID > 0)
		{
			AIUnitData = XComGameState_AIUnitData(NewGameState.ModifyStateObject(class'XComGameState_AIUnitData', AIUnitDataID));
			if(AIUnitData.m_arrAlertData.Length > 0)
			{
				// Clear out all alert data
				AIUnitData.m_arrAlertData.Length = 0;
				//`Log("Pod Job Manager Removing All Alert Data from unit# "$Unit.ObjectID);
			}
			else
			{   
				// No alert data found
				NewGameState.PurgeGameStateForObjectID(AIUnitData.ObjectID);
			} 
		}
	}
}