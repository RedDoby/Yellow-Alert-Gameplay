Yellow Alert Gameplay improves the AI's decision making process for tactical pod movement prior to engagement, providing a more realistic approach to how the AI respond to Xcom's position on the map.  All gameplay cheats have been removed.  The enemy now uses the following alerts to control green and yellow alert movement prior to engagement:

Detected New Corpse
Detected Ally Taking Damage
Detected Sound
Alerted By Yell (Caused by Civilians)
Sees Explosion - actually works by hearing explosion
Sees Alerted Allies

By introducing the pod job manager from LW2, enemy pods will now do more than just run towards the alert like they did in the original version of yellow alert gameplay.  The pod manager assigns certain jobs for patrolling pods or groups.  The jobs they can take depends on the mission and a variety of other factors.  Below is a list of the jobs a patrolling and unengaged pod can be assigend along with a description of each:

Guard - Move to the objective but once you reach it, find a new job
Defend - Move and patrol a small area around the objective.  This job is indefinite.
Intercept Xcom - Move toward Xcom's last known position.  The last known position is updated each time someone from the alien team sees Xcom or when important alerts are known by the alien team.  All pods on the alien team are aware of this location.  
Flank - sets up a 3 phase flank move in an attempt to flank Xcom's last known position.
Block Xcom - Block Xcom's path to the objective by moving in between their last known position and the objective.  Once they reach this location they will be assigned a new job.  
Scout -  This jobs only gets assigned once a pod has investigated Xcom's last known position via the intercept or flank jobs and Xcom is not there anymore.  The pod will then attempt to scout the area until Xcom is spotted again.
Defend Evac Zone - This job kicks in if the alien team has spotted Xcom's evac zone and only after the objective has been completed.  They will send a pod to permanently patrol a small area around the evac zone so Xcom can't escape.  

Green and yellow reflex actions
During the alien turn, enemy units that are in green alert now have a chance to gain an extra Defensive action point once revealed.  The chance to roll for an extra varies depending on how many tiles the unit moved prior to revealing. For example, a unit that moved one tile has a much greater chance to receive an extra action than a unit that moved 5 spaces.  Basically, the concept here is that we are trying to refund back the action point that the unit may have lost for having revealed and their movement being interrupted. Defensive action points are set in the yellowalert.ini, and limited to mainly overwatching, energy shield, and other defensive actions.

Units in yellow alert, who are suspicious, and aware of a threat, have the same chance to roll for an extra action, but will receive a standard action point that will allow them to use any action for their character. 

This feature can be disabled and the chances configured in the config file.

Rapid Reinforcements
Reinforcement units receive an extra action point, giving them a full turn when they drop in.  This feature can be disabled and the chances configured in the config file.

Any units that are injured during reinforcement or scamper have their regular action point replaced with a defensive action point and are limited to the defensive actions set in the ini.

Many Configuration options in this mods config/XcomYellowAlert.ini.
Upthrottling and downthrottling can be enabled in config/XcomAI.ini by adding semicolins or deleting to the last six lines.

Because of the added difficulty I recommend using Dynamic Encounter Zones to spread out the pods on the map. https://steamcommunity.com/sharedfiles/filedetails/?id=1854949514

Thanks to the long war mod I was able to borrow most of the code from them.

Safe to add or remove mid campaign, but not during tactical.

This version of yellow alert gameplay requires the community highlander beta which is why I am calling it a beta.  I have tested this extensively without any issues.  By using the highlander beta I am able to eliminate several mod class overrides, but unfortunately still have to override a few classes listed below:

Mod Class Overrides
XComGameState_AIUnitData
XGAIBehavior
XGAIBehavior_Civilian
YellowAlert_XGAIPatrolGroup 

One Final Note
Since I am already overriding XComGameState_AIUnitData and XGAIBehavior, I have added a fix to the game that is currectly in the works to be added to the community highlander. It is a very important fix IMO.  In the vanilla game, AI teams (Resistance, Raider Factions, Alienss) don't consider each other when positioning movement for cover and flanking.  Which is why you always see them getting into a flank position when battling each other.  The fix applied here corrects that by including them in the known enemy list when making movement decisions while engaged.  

Mod Conflicts
Dynamic Pod Activation
