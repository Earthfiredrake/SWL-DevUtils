# SWL-DevUtils
A rather random collection of tools for SWL that I've used when developing mods or for personal curiosity
Most features are controlled by DVs named `efdDevUtil*`

## Dynel Data Dumps
  Data for various dynels is dumped to the system chat and log file (for later parsing). By default it's mostly location info, occasionally specialized for various Cartographer data formats.
  + `efdDevUtilDump` (bool, self-resets): Triggers a data dump for the dynel under the targeting reticle (when it has changed to a non-grey colour). `/tdd` (target data dump) script is provided as a shorthand
  + `efdDevUtilDumpSelf` (bool, self-resets): Triggers the data dump for the player avatar dynel
  + `efdDevUtilProxScan` (bool): Toggles data dumps for any dynel that enters proximity (useful for invisible/non-targeted dynels).
  + 'efdDevUtilTrack' (bool): Uses targeting reticle, and toggles tracking the target, providing an onscreen waypoint and repeated data point generation (used for paths of roaming monsters). Repeat frequency is controlled by `efdDevUtilTrackingInterval` (int), and the `/track` script is provided as a shorthand to start.
  
  Additional data can be added to the chat dump by setting the value of:
  + `efdDevUtilDumpFull` (bool): Probes the first 2500000 entries in the dynel's GetStat function, returning any that appear interesting (are nonzero). WARNING very slow, particularly bad when combined with ProxScan or Tracking.
  + `efdDevUtilDumpSingle` (int): Set to a particular GetStat index which will then be reported.
  + `efdDevUtilDumpMissions` (bool): Dumps additional mission data from quest givers
  
 ## General Data Dumps
 + `efdDevUtilShowDV` (string): Setting this to the name of another DV should output that DV's value to chat (for when `/setoption` is bugged)
 + `efdDevUtilInspectArchive` (string): Setting this to the name of a known archive will dump the archive contents to chat
 + `efdDevUtilDumpNoRepeatMissions` (bool, self-resets): Dumps names and IDs of unrepeatable missions that have already been completed to chat and logfile
 + `efdDevUtilDumpLoreIDs` (bool, self-resets): Dumps the lore topic tree to the logfile
 + `efdDevUtilDumpAchievementIDs` (bool, self-resets): Dumps the achievement title tree to the logfile
 + `efdDevUtilProbeAgents` (bool, self-resets): Currently dumps the required Agent XP for each level
 + `efdDevUtilTrackBuffs` (bool): Attempts to track character buffs in chat as they are added, updated and removed
 + Inventory item data: Right clicking on an item in any inventory window will dump some info about that item to system chat (in addition to the usual use effect, careful around those vendors). No toggle for this one just yet.
 
 ## Python Scripts
  A script for pulling TDD flagged entries from the logfile (expects to run in the mod's install directory), and a couple of data wranglers for converting coordinate data into other forms for Cartographer.
  