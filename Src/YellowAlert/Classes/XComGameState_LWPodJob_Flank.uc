//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodJob_Flank.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: Pod Job to attempt to flank XCOM. This job is divided into three phases:
//           the first (setup) phase moves the pod to a position offset from XCOM out of 
//           sight range, perpendicular to their current position in the line of play. 
//			 Once they reach this point the second phase kicks in and moves the pod to 
//			 a position offset from XCOM out of sight range, perpendicular to XCom's position 
//			 in the line of play. Once they reach this point the
//           third phase kicks in, and they move to XCOM's position.
//---------------------------------------------------------------------------------------
class XComGameState_LWPodJob_Flank extends XComGameState_LWPodJob_MoveToLocation;

`include(YellowAlert\Src\extra_globals.uci)

var config const int FLANK_DISTANCE;

// Have we reached the second phase?
var bool MovingToPhase2;
// Have we reached the third phase?
var bool MovingToIntercept;
// Keep Track of which direction we are flanking right or left (Facing Xcom from the group's location)
var String FlankDirection;

// Determine a location perpendicular to the group's midpoint
function Vector GetFlankingLocation1(XComGameState_AIGroup Group)
{
    local TwoVectors CurrentLineOfPlay;
    local Vector TmpLoc;
    local Vector Perp[2];
    local Vector GroupLocation;
	local vector GroupLocationOnAxis;
    local Vector XComLocation;
    local Vector TargetLoc;
    local XGAIPlayer AIPlayer;
    local XComWorldData World;
    local TTile Tile[2];

    World = `XWORLD;
    AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
    AIPlayer.m_kNav.UpdateCurrentLineOfPlay(CurrentLineOfPlay);

    // Determine the point to set up the flank. This is a point
    // perpendicular to the LoP, offset from the Group's closest point
    // by FLANK_DISTANCE units to the left or right of the LoP.

    // First: get a vector parallel to the (assumed) Line of Play.
    XComLocation = `LWPODMGR.GetLastKnownXComPosition();

	// 84,32 - 9,22 = 75,10 
    TmpLoc = XComLocation - CurrentLineOfPlay.v2;

    // Shrink to the unit vector
    TmpLoc = Normal(TmpLoc);

    // And scale by the desired offset
    TmpLoc *= `TILESTOUNITS(default.FLANK_DISTANCE);

    // Compute the perpendicular vectors: rotate the vector
    // clockwise and counterclockwise by 90 degrees.
    
    // Perp[0]: Clockwise
	// 10,-75
    Perp[0].X = TmpLoc.Y;
    Perp[0].Y = -TmpLoc.X;

    // Perp[1]: Counterclockwise
	// -10,75
    Perp[1].X = -TmpLoc.Y;
    Perp[1].Y = TmpLoc.X;

	GroupLocation = Group.GetGroupMidpoint();
	// Get closest point from group to the assumed line of play
	GroupLocationOnAxis = class'XGAIPlayerNavigator'.static.GetClosestPointAlongLineToTestPoint( XComLocation, CurrentLineOfPlay.v2, GroupLocation );
    // Add the perpendicular vectors to the group's position to get our candidates.
	// 19,-53
    Perp[0] += GroupLocationOnAxis;
	// -1,97
    Perp[1] += GroupLocationOnAxis;

    // If one is off-map, choose the other (note that if they're both off map, XCOM is probably
    // near a corner. That's ok, we won't be able to flank but we can get close-ish, and the super
    // class Init will adjust the alert location to the closest legal tile.
    Tile[0] = World.GetTileCoordinatesFromPosition(Perp[0]); 
    Tile[1] = World.GetTileCoordinatesFromPosition(Perp[1]); 
    if (World.IsTileOutOfRange(Tile[0]))
    {
        TargetLoc = Perp[1];
		FlankDirection = "Left";
    }
    else if (World.IsTileOutOfRange(Tile[1]))
    {
        TargetLoc = Perp[0];
		FlankDirection = "Right";
    }
    else
    {
        // Both are on-map, find the one closer to this group's location.
        
        if (VSizeSq(Perp[0] - GroupLocation) < VSizeSq(Perp[1] - GroupLocation))
        {
            TargetLoc = Perp[0];
			FlankDirection = "Right";
        }
        else
        {
            TargetLoc = Perp[1];
			FlankDirection = "Left";
        }
    }

    return TargetLoc;
}

function Vector GetFlankingLocation2()
{
    local TwoVectors CurrentLineOfPlay;
    local Vector TmpLoc;
    local Vector Perp[2];
    local Vector XComLocation;
    local Vector TargetLoc;
    local XGAIPlayer AIPlayer;

    AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
    AIPlayer.m_kNav.UpdateCurrentLineOfPlay(CurrentLineOfPlay);

    // Determine the point to set up the flank. This is a point
    // perpendicular to the LoP, offset from the XCOM midpoint
    // by FLANK_DISTANCE units to the left or right of the LoP.

    // First: get a vector parallel to the (assumed) Line of Play.
    XComLocation = `LWPODMGR.GetLastKnownXComPosition();
    TmpLoc = XComLocation - CurrentLineOfPlay.v2;

    // Shrink to the unit vector
    TmpLoc = Normal(TmpLoc);

    // And scale by the desired offset
    TmpLoc *= `TILESTOUNITS(default.FLANK_DISTANCE);

    // Compute the perpendicular vectors: rotate the vector
    // clockwise and counterclockwise by 90 degrees.
    
    // Perp[0]: Clockwise
    Perp[0].X = TmpLoc.Y;
    Perp[0].Y = -TmpLoc.X;

    // Perp[1]: Counterclockwise
    Perp[1].X = -TmpLoc.Y;
    Perp[1].Y = TmpLoc.X;

    // Add the perpendicular vectors to XCOM's position to get our candidates.
    Perp[0] += XComLocation;
    Perp[1] += XComLocation;
    
    if (FlankDirection == "Left")
    {
        TargetLoc = Perp[1];
    }
    else
    {
        TargetLoc = Perp[0];
    }

    return TargetLoc;
}

function InitJob(LWPodJobTemplate JobTemplate, XComGameState_AIGroup Group, int JobID, EAlertCause Cause, String Tag, XComGameState NewGameState)
{
    Location = GetFlankingLocation1(Group);
    super.InitJob(JobTemplate, Group, JobID, Cause, Tag, NewGameState);
}

function bool ProcessTurn(XComGameState_LWPodManager PodMgr, XComGameState NewGameState)
{
    local XComGameState_AIGroup Group;
    local XComGameState_AIPlayerData AIPlayerData;
    local Vector NewXComPos, Flank1, Flank2;

    Group = XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
    NewXComPos = PodMgr.GetLastKnownXComPosition();

    // First, check to see if we're in position. If so, move to phase 3.
    if (!MovingToIntercept)
    {
		// First, check to see if we're in position. If so, move to phase 2.
		if (!MovingToPhase2)
		{
			// Compute a new flanking location if xcom's known position has moved, but don't change
			// our alert yet: we might be moving to phase 2.
			Flank1 = GetFlankingLocation1(Group);
			Flank1 = AdjustLocation(Flank1, Group);

			// Have we reached the first flank point? Is it time to move to phase 2 yet?
			if (VSizeSq(Group.GetGroupMidpoint() - Flank1) <= DESTINATION_REACHED_SIZE_SQ)
			{
				// We've made it to the first position. Get 2nd flanking position.
				MovingToPhase2 = true;
				Flank2 = GetFlankingLocation2();
				Flank2 = AdjustLocation(Flank2, Group);
				Location = SetAlertAtLocation(Flank2, Group, NewGameState);
				// Reset our turn count: we're making progress.
				AIPlayerData = GetAIPlayerData();
				InitTurn = AIPlayerData.StatsData.TurnCount;
			}
			else if (Flank1 != Location)
			{
				// We're not close enough yet, but we have a new flank location. Move there.
				Location = SetAlertAtLocation(Flank1, Group, NewGameState);
			}
		}
		// We are at phase 2
		else
		{
			// Compute a new flanking location if xcom's known position has moved, but don't change
			// our alert yet: we might be moving to engage.
			Flank2 = GetFlankingLocation2();
			Flank2 = AdjustLocation(Flank2, Group);

			// Is it time to engage yet?
			if (ShouldEngage(Group, PodMgr, Flank2))
			{
				MovingToIntercept = true;
				Location = SetAlertAtLocation(NewXComPos, Group, NewGameState);
				// Reset our turn count: we're making progress.
				AIPlayerData = GetAIPlayerData();
				InitTurn = AIPlayerData.StatsData.TurnCount;
			}
			else if (Flank2 != Location)
			{
				// We're not close enough yet, but we have a new flank location. Move there.
				Location = SetAlertAtLocation(Flank2, Group, NewGameState);
			}
		}
    }
    else
    {
        // We're engaging. Do we need to update based on XCOM's new location?
        if (Location != NewXComPos)
        {
            Location = SetAlertAtLocation(NewXComPos, Group, NewGameState);
        }
    }

    // If we're still getting into position, only cancel this job if we time out. Otherwise
    // we can cancel if we got where we thought XCOM was but nobody was there or the job timed out.
    if (!MovingToIntercept)
    {
        return !HasJobExpired();
    }
    else
    {
		// If we are engaging and have reached the location we thought XCom was at 
		// then we are finished
		if (HasReachedDestination())
		{ 
			// Mark that XCom's position has been investigated and nothing was found
			PodMgr.XComPositionInvestigatedTurn = class'HelpersYellowAlert'.static.FindPlayer(eTeam_Alien).PlayerTurnCount;
			return false;
		}
		else
		{	
			return !HasJobExpired();
		}
    }
}

function bool ShouldEngage(XComGameState_AIGroup Group, XComGameState_LWPodManager PodMgr, Vector TargetLocation)
{
    local XComGameState_AIPlayerData AIPlayerData;
    local XComGameState_LWPodJob OtherJob;
    local XComGameState_AIGroup OtherGroup;
    local XComGameStateHistory History;
    local int i;

    if (VSizeSq(Group.GetGroupMidpoint() - TargetLocation) > DESTINATION_REACHED_SIZE_SQ)
    {
        // We're not close enough yet. Keep going.
        return false;
    }

    // Is XCOM engaged? Now's a great time to move in.
    AIPlayerData = PodMgr.GetAIPlayerData();
    if (AIPlayerData.StatsData.NumEngagedAI > 0)
    {
        return true;
    }

    History = `XCOMHISTORY;

    // Are any other pods with jobs also close to xcom, e.g. are they about as close to xcom as we are?
    for (i = 0; i < PodMgr.ActiveJobs.Length; ++i)
    {
        if (PodMgr.ActiveJobs[i].ObjectID == ObjectID)
            continue;

        OtherJob = XComGameState_LWPodJob(History.GetGameStateForObjectID(PodMgr.ActiveJobs[i].ObjectID));
        OtherGroup = XComGameState_AIGroup(History.GetGameStateForObjectID(OtherJob.GroupRef.ObjectID));
        if (VSizeSq(OtherGroup.GetGroupMidpoint() - PodMgr.GetLastKnownXComPosition()) <= 
            (`TILESTOUNITS(FLANK_DISTANCE) * `TILESTOUNITS(FLANK_DISTANCE)))
        {
            return true;
        }
    }

    // Nobody else appears close by. If there is anyone else with a job, we'll hang tight and wait. If
    // this is the only pod with a job, move in.
    return PodMgr.ActiveJobs.Length == 1;
}

function String GetDebugString()
{
    local String str;

    str = super.GetDebugString();
    if (MovingToIntercept)
    {
        str $= " (Engaging)";
    }
	else if (MovingToPhase2)
	{
		if (HasReachedDestination())
		{
			str $= " (Waiting)";
		}
		else
		{
			str $= " (Positioning 2nd Phase)";
		}
	}
	else
    {
        str $= " (Positioning 1st Phase)";
    }

    return str;
}
