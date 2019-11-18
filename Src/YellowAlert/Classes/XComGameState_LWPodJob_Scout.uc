//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodJob_MoveToLocation.uc
//  AUTHOR:  RedDobe
//  PURPOSE: A pod job to move to a allow pods to scout the map.
//---------------------------------------------------------------------------------------
class XComGameState_LWPodJob_Scout extends XComGameState_LWPodJob config(LW_PodManager);

function InitJob(LWPodJobTemplate JobTemplate, XComGameState_AIGroup Group, int JobID, EAlertCause Cause, String Tag, XComGameState NewGameState)
{
    super.InitJob(JobTemplate, Group, JobID, Cause, Tag, NewGameState);

    RemoveAlertsFromGroup(Group, NewGameState);
}