//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodJob_MoveToLocation.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: A pod job to move to a particular location on the map.
//---------------------------------------------------------------------------------------
class XComGameState_LWPodJob_MoveToLocation extends XComGameState_LWPodJob config(LW_PodManager);

`include(YellowAlert\Src\extra_globals.uci)

var config const int DESTINATION_REACHED_SIZE_SQ;

// The target location
var Vector Location;

// Should we keep this job after we reach the destination?
var bool KeepJobAfterReachingDestination;

function InitJob(LWPodJobTemplate JobTemplate, XComGameState_AIGroup Group, int JobID, EAlertCause Cause, String Tag, XComGameState NewGameState)
{
    super.InitJob(JobTemplate, Group, JobID, Cause, Tag, NewGameState);

    Location = SetAlertAtLocation(Location, Group, NewGameState);
}

function bool ProcessTurn(XComGameState_LWPodManager PodMgr, XComGameState NewGameState)
{
    local Vector NewDestination;
    local XComGameState_AIGroup Group;
    local LWPodJobTemplate Template;

	// Check if the job that we are about to remove is defined in the JobsToGiveScoutJob array
	// And whether or not Xcom's last known position has been investigated
	// If true than we want to end this job and 
	// give them the scout job as a replacement (UpdatePod in LWPodManager)

	if(PodMgr.JobsToGiveScoutJob.Find(GetMyTemplateName()) >= 0 &&
	PodMgr.XComPositionInvestigatedTurn > PodMgr.LastKnownXComPositionTurn)
	{
		//`log("XCom Position has been investigated - ending "$GetMyTemplateName()$" job");
		return false;
	}

    if (!ShouldContinueJob(NewGameState))
    {
        return false;
    }

    Template = GetMyTemplate();

    if (Template.GetNewDestination != none)
    {
        NewDestination = Template.GetNewDestination(self, NewGameState);
		Group = XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
        if (Location != AdjustLocation(NewDestination, Group))
        {   
            Location = SetAlertAtLocation(NewDestination, Group, NewGameState);
        }
    }

    return true;
}

function XComGameState_AIGroup GetGroup()
{
    return XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
}

function bool HasReachedDestination()
{
	local XComGameState_AIGroup Group;

	Group = GetGroup();
    return (VSizeSq(Group.GetGroupMidpoint() - Location) < DESTINATION_REACHED_SIZE_SQ);
}

function bool ShouldContinueJob(XComGameState NewGameState)
{
	local XComGameState_LWPodManager PodMgr, NewPodMgr;
	local XComGameState_AIPlayerData AIPlayerData;
    // Have we reached our destination?
    if (HasReachedDestination())
    {
		// Reset the initiated turn count for the jobs that are indefinite i.e. Defend
		// This is needed because the super.ShouldCountinueJob will remove the job for defend after the timeout period
		// since defend patrols around the objective and doesn't reach it's destination every turn
		if (KeepJobAfterReachingDestination)
		{
			AIPlayerData = GetAIPlayerData();
			InitTurn = AIPlayerData.StatsData.TurnCount;
		}
		// Mark that XCom's position has been investigated and nothing was found
		if(GetMyTemplateName() == 'Intercept')
		{
			PodMgr = `LWPODMGR;
			NewPodMgr = XComGameState_LWPodManager(NewGameState.GetGameStateForObjectID(PodMgr.ObjectID));
			if (NewPodMgr != none)
			{
				PodMgr = NewPodMgr;
			}
			PodMgr.XComPositionInvestigatedTurn = class'HelpersYellowAlert'.static.FindPlayer(eTeam_Alien).PlayerTurnCount;
		}
        // We're here!
        return KeepJobAfterReachingDestination;
    }

    // We haven't yet arrived. Use the standard mechanism to allow job timeouts if they can't get
    // to the destination, even if they would keep the job forever after getting there.
    if (!super.ShouldContinueJob(NewGameState))
    {
        return false;
    }

    return true;
}

function String GetDebugString()
{
    return Super.GetDebugString() $ " @ " $ Location;
}

function DrawDebugLabel(Canvas kCanvas)
{
    local XComGameState_AIGroup Group;
    local Vector CurrentGroupLocation;
    local Vector ScaleVector;
    local SimpleShapeManager ShapeManager;

    Group = XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
    CurrentGroupLocation = Group.GetGroupMidpoint();
    
    ScaleVector = vect(64, 64, 64);
    ShapeManager = `SHAPEMGR;

    ShapeManager.DrawSphere(CurrentGroupLocation, ScaleVector, MakeLinearColor(0, 0.75, 0.75, 1));
    ShapeManager.DrawSphere(Location, ScaleVector, MakeLinearColor(0.75, 0, 0.75, 1));
    ShapeManager.DrawLine(CurrentGroupLocation, Location, 8, MakeLinearColor(0, 0.75, 0.75, 1));
}

