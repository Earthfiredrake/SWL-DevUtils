// Copyright 2017-2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-DevUtils

import flash.geom.Point;

import com.GameInterface.AgentSystem;
import com.GameInterface.AgentSystemAgent;
import com.GameInterface.AgentSystemMission;
import com.GameInterface.DistributedValue;
import com.GameInterface.DressingRoom;
import com.GameInterface.Dynels;
import com.GameInterface.Game.BuffData;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.Dynel;
import com.GameInterface.Inventory;
import com.GameInterface.InventoryItem;
import com.GameInterface.Log;
import com.GameInterface.Lore;
import com.GameInterface.LoreNode;
import com.GameInterface.MathLib.Vector3;
import com.GameInterface.Quest;
import com.GameInterface.QuestGiver;
import com.GameInterface.Quests;
import com.GameInterface.Utils;
import com.GameInterface.VicinitySystem;
import com.GameInterface.Waypoint;
import com.Utils.Archive;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import GUI.Waypoints.CustomWaypoint;

var AgentMissionTesting:DistributedValue;
var TargetDataDumpTrigger:DistributedValue;
var TargetTrackingTrigger:DistributedValue;
var SingleStatDump:DistributedValue;
var FullStatDump:DistributedValue;
var MissionInfoDump:DistributedValue;
var NoRepeatMissionDump:DistributedValue;
var InspectArchiveDV:DistributedValue;
var LoreIDDumpTrigger:DistributedValue;
var AchievementIDDumpTrigger:DistributedValue;
var ProximityScanner:DistributedValue;
var DVProbe:DistributedValue;

var AgentWindow:DistributedValue;

var ClientChar:Character;
var WaypointSystem:Object;
var TrackingTarget:Dynel = null;
var TrackingTargetID:ID32 = null;
var TargetTrackingInterval:Number;
var IntervalLength:DistributedValue;

function onLoad():Void {
	if (!_global.efd) { _global.efd = new Object(); }
	if (!_global.efd.DevUtils) { _global.efd.DevUtils = new Object(); }
	
	ProximityScanner = DistributedValue.Create("efdDevUtilProxScan");
	ProximityScanner.SetValue(false);
	ProximityScanner.SignalChanged.Connect(ToggleProximityScan, this);
	TargetDataDumpTrigger = DistributedValue.Create("efdDevUtilDump");
	TargetDataDumpTrigger.SetValue(false);
	TargetDataDumpTrigger.SignalChanged.Connect(TargetDataDump, this);
	SelfDumpTrigger = DistributedValue.Create("efdDevUtilDumpSelf");
	SelfDumpTrigger.SetValue(false);
	SelfDumpTrigger.SignalChanged.Connect(SelfDataDump, this);
	TargetTrackingTrigger = DistributedValue.Create("efdDevUtilTrack");
	TargetTrackingTrigger.SetValue(false);
	TargetTrackingTrigger.SignalChanged.Connect(TrackTarget, this);
	IntervalLength = DistributedValue.Create("efdDevUtilTrackingInterval");
	IntervalLength.SetValue(1000);
	WaypointSystem = _root.waypoints;
	Dynels.DynelGone.Connect(TargetDespawned, this);
	
	FullStatDump = DistributedValue.Create("efdDevUtilDumpFull");
	FullStatDump.SetValue(false);
	SingleStatDump = DistributedValue.Create("efdDevUtilDumpSingle");
	SingleStatDump.SetValue(0);
	MissionInfoDump = DistributedValue.Create("efdDevUtilDumpMissions");
	MissionInfoDump.SetValue(false);
	
	DVProbe = DistributedValue.Create("efdDevUtilShowDV");
	DVProbe.SignalChanged.Connect(ShowDV, this);
	
	NoRepeatMissionDump = DistributedValue.Create("efdDevUtilDumpNoRepeatMissions");
	NoRepeatMissionDump.SetValue(false);
	NoRepeatMissionDump.SignalChanged.Connect(NRMissionDump, this);
	
	LoreIDDumpTrigger = DistributedValue.Create("efdDevUtilDumpLoreIDs");
	LoreIDDumpTrigger.SetValue(false);
	LoreIDDumpTrigger.SignalChanged.Connect(DumpLore, this);
	AchievementIDDumpTrigger = DistributedValue.Create("efdDevUtilDumpAchievementIDs");
	AchievementIDDumpTrigger.SetValue(false);
	AchievementIDDumpTrigger.SignalChanged.Connect(DumpAchievements, this);
	
	AgentMissionTesting = DistributedValue.Create("efdDevUtilProbeAgents");
	AgentMissionTesting.SetValue(false);
	AgentMissionTesting.SignalChanged.Connect(ProbeAgents, this);
	
	InspectArchiveDV = DistributedValue.Create("efdDevUtilInspectArchive");
	InspectArchiveDV.SignalChanged.Connect(InspectArchive, this);
	
	ClientChar = Character.GetClientCharacter();
	TrackBuffsDV = DistributedValue.Create("efdDevUtilTrackBuffs");
	TrackBuffsDV.SetValue(false);
	TrackBuffsDV.SignalChanged.Connect(TrackBuffs, this);	
	
	HookInventoryWatcher(0);
}

function ShowDV(dv:DistributedValue):Void {
	var target:String = dv.GetValue();
	if (target) {
		var out:String = "Variable " + target + " ";
		if (DistributedValue.DoesVariableExist(target)) {
			out += "has value " + DistributedValue.GetDValue(target);
		} else {
			out += "does not exist";
		}
		Utils.PrintChatText(out);
		dv.SetValue(null);
	}
}

function HookInventoryWatcher(retry:Number):Void {
	if (_global.efd.DevUtils.InventoryHooked) { return; }
	var proto:Object = _global.com.GameInterface.Inventory.prototype;
	if (!proto) {
		Utils.PrintChatText("Unable to find inventory prototype, attempt " + retry + " (of 5)");
		if (retry < 5) { setTimeout(Delegate.create(this, HookInventoryWatcher), 50, retry+1); }
		return;
	}
	var wrapper:Function = function(itemPos:Number):Void {
		var item:InventoryItem = this.GetItemAt(itemPos);
		Utils.PrintChatText("Inventory ID: " + this.GetInventoryID().toString()); // m_Type matches with instances of _global.Enums.InvType
		Utils.PrintChatText("Item info for used item: " + item.m_Name);
		Utils.PrintChatText("  IconID: " + item.m_Icon.toString());
		Utils.PrintChatText("  Position: " + item.m_InventoryPos);
		Utils.PrintChatText("  Stack: " + item.m_StackSize + "/" + item.m_MaxStackSize);
		Utils.PrintChatText("  Placement: " + item.m_Placement);
		Utils.PrintChatText("  DefaultPos: " + item.m_DefaultPosition);
		Utils.PrintChatText("  Type: " + item.m_Type);
		Utils.PrintChatText("  ItemType: " + item.m_ItemType);
		Utils.PrintChatText("  AegisType: " + item.m_AegisItemType);
		Utils.PrintChatText("  ItemTypeGUI: " + item.m_ItemTypeGUI);
		Utils.PrintChatText("  RealType: " + item.m_RealType);
		Utils.PrintChatText("  Locked: " + item.m_Locked);
		Utils.PrintChatText("  Deleteable: " + item.m_Deleteable);
		Utils.PrintChatText("  Unique: " + item.m_Unique);
		Utils.PrintChatText("  BoP: " + item.m_IsBindOnPickup);
		Utils.PrintChatText("  NoDropUse: " + item.m_IsNoDropOnUse);
		Utils.PrintChatText("  Bound: " + item.m_IsBoundToPlayer);
		Utils.PrintChatText("  CanUse: " + item.m_CanUse);
		Utils.PrintChatText("  Can Buy: " + item.m_CanBuy);
		if (item.m_IsACGItem) {
			Utils.PrintChatText("  ACGItem data");
			Utils.PrintChatText("    TemplateID0: " + item.m_ACGItem.m_TemplateID0);
			Utils.PrintChatText("    TemplateID1: " + item.m_ACGItem.m_TemplateID1);
			Utils.PrintChatText("    TemplateID2: " + item.m_ACGItem.m_TemplateID2);
			Utils.PrintChatText("    Level: " + item.m_ACGItem.m_Level);
			Utils.PrintChatText("    Prefix Lvl: " + item.m_ACGItem.m_PrefixLevel);
			Utils.PrintChatText("    Suffix Lvl: " + item.m_ACGItem.m_SuffixLevel);
			Utils.PrintChatText("    Decryption Array 0: " + item.m_ACGItem.m_DecryptionKey0);
			Utils.PrintChatText("    Decryption Array 1: " + item.m_ACGItem.m_DecryptionKey1);
			Utils.PrintChatText("    Decryption Array 2: " + item.m_ACGItem.m_DecryptionKey2);
		}
		Utils.PrintChatText("  Item Tier/Level/XP: " + item.m_Rarity + "/" + item.m_Rank + "/" + item.m_XP);
		Utils.PrintChatText("  Pips: " + item.m_Pips);
		if (item.m_HasRemovableSuffix) { // Has Glyph
			Utils.PrintChatText("  Glyph Tier/Level/XP: " + item.m_GlyphRarity + "/" + item.m_GlyphRank + "/" + item.m_GlyphXP);
		}
		if (item.m_HasRemovablePrefix) { // Has Signet
			Utils.PrintChatText("  Signet Tier/Level/XP: " + item.m_SignetRarity + "/" + item.m_SignetRank + "/" + item.m_SignetXP);
		}
		//Utils.PrintChatText("  Colour: " + item.m_ColorLine);
		//Utils.PrintChatText("  InFilter: " + item.m_InFilter);
		//Utils.PrintChatText("  Sell Price: " + item.m_SellPrice);
		//Utils.PrintChatText("  Buy Price: " + item.m_BuyPrice);
		//Utils.PrintChatText("  CooldownStart: " + item.m_CooldownStart);
		//Utils.PrintChatText("  CooldownEnd: " + item.m_CooldownEnd);
		//Utils.PrintChatText("  Repair Price: " + item.m_RepairPrice);
		//Utils.PrintChatText("  Durability: " + item.m_Durability + "/" + item.m_MaxDurability);
		//Utils.PrintChatText("  Token Currency Buy 1: " + item.m_TokenCurrencyType1 + "(" + item.m_TokenCurrencyPrice1 + ")");
		//Utils.PrintChatText("  Token Currency Buy 2: " + item.m_TokenCurrencyType2 + "(" + item.m_TokenCurrencyPrice2 + ")");
		//Utils.PrintChatText("  Token Currency Sell 1: " + item.m_TokenCurrencySellType1 + "(" + item.m_TokenCurrencySellPrice1 + ")");
		//Utils.PrintChatText("  Token Currency Sell 2: " + item.m_TokenCurrencySellType2 + "(" + item.m_TokenCurrencySellPrice2 + ")");
		//Utils.PrintChatText("  Discount: " + item.m_Discount);
		//Utils.PrintChatText("  BuyLimit: " + item.m_BuyLimit + "/" + item.m_MaxBuyLimit);


		arguments.callee.base.apply(this, arguments);			
	};
	wrapper.base = proto.UseItem;
	proto.UseItem = wrapper;
	_global.efd.DevUtils.InventoryHooked = true;
	Utils.PrintChatText("Use item data dump applied");
}

function OnUnload():Void {
	TargetTrackingTrigger.SetValue(false);
}

function ProbeAgents(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		var prev:Number = 0;
		for (var i:Number = 0; i < 51; ++i) {
			var here:Number = AgentSystem.GetAgentXPForLevel(i);			
			Utils.PrintChatText("AgentXP Levels (" + i + ", " + here + ", +" + (here - prev) +")");
			prev = here;
		}
	}
	dv.SetValue(false);
}

function ToggleProximityScan(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		VicinitySystem.SignalDynelEnterVicinity.Connect(ProximityPing, this);
	} else {
		VicinitySystem.SignalDynelEnterVicinity.Disconnect(ProximityPing, this);
	}	
}

function ProximityPing(dynelId:ID32):Void {
	var dynel:Dynel = Dynel.GetDynel(dynelId);
	if (dynel) { DumpData(Dynel.GetDynel(dynelId)); }
	else { Utils.PrintChatText("TDD: Undefined Dynel: " + dynelId.toString()); }
}

function InspectArchive(dv:DistributedValue):Void {
	var aName:String = dv.GetValue();
	if (aName) {
		var archive:Archive = DistributedValue.GetDValue(dv.GetValue());
		if (!archive) { Utils.PrintChatText("Archive does not exist: " + aName); }
		else { if (!(archive instanceof Archive)) { Utils.PrintChatText("DV is not an archive: " + aName + " (" + archive + ")"); }
			else {
				Utils.PrintChatText("Archive Contents: " + aName); }
				for (var key:String in archive["m_Dictionary"]) {
					Utils.PrintChatText("  " + key + " : " + archive["m_Dictionary"]["key"]);
				}
			}
	}
	dv.SetValue(undefined);
}

function TrackBuffs(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		ClientChar.SignalBuffAdded.Connect(BuffAdded, this);
		ClientChar.SignalBuffUpdated.Connect(BuffUpdated, this);
		ClientChar.SignalBuffRemoved.Connect(BuffRemoved, this);
		ClientChar.SignalInvisibleBuffAdded.Connect(InBuffAdded, this);
    	ClientChar.SignalInvisibleBuffUpdated.Connect(InBuffUpdated, this);
	} else {
		ClientChar.SignalBuffAdded.Disconnect(BuffAdded, this);
		ClientChar.SignalBuffUpdated.Disconnect(BuffUpdated, this);
		ClientChar.SignalBuffRemoved.Disconnect(BuffRemoved, this);
		ClientChar.SignalInvisibleBuffAdded.Disconnect(InBuffAdded, this);
    	ClientChar.SignalInvisibleBuffUpdated.Disconnect(InBuffUpdated, this);
	}
}

function BuffAdded(buffID:Number):Void { NoteBuff("Added", buffID); }
function BuffUpdated(buffID:Number):Void { NoteBuff("Updated", buffID); }
function BuffRemoved(buffID:Number):Void { NoteBuff("Removed", buffID); }
function InBuffAdded(buffID:Number):Void { NoteBuff("Added", buffID, true); }
function InBuffUpdated(buffID:Number):Void { NoteBuff("Updated", buffID, true); }

function NoteBuff(trigger:String, buffID:Number, invis:Boolean):Void {
	var buffName:String = LDBFormat.Translate("<localized category=50210 id=" + buffID + " />");
	Utils.PrintChatText((invis ? "Invisible " : "") + "Buff " + trigger + " : " + buffName + " (" + buffID + ")");
}

function DumpLore(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		TagDump(Lore.GetLoreTree(), 0);
	}
	dv.SetValue(false);
}

function DumpAchievements(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		TagDump(Lore.GetAchievementTree(false), 0);
	}
	dv.SetValue(false);
}

function TagDump(tree:LoreNode, depth:Number):Void {
	var out:String = tree.m_Id + " : " + tree.m_Name;
	for (var i:Number = 0; i < depth; ++i) {
		out = "\t" + out;
	}
	Log.Error("TDD", out);
	for (var i:Number = 0; i < tree.m_Children.length; ++i) {
		TagDump(tree.m_Children[i], depth + 1);
	}
}

function TargetDataDump(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		var target:Dynel = _root.crosshaircontroller.m_Dynel;
		if (target) { DumpData(target); }
	}
	dv.SetValue(false);
}

function SelfDataDump(dv:DistributedValue):Void {
	if (dv.GetValue()) {
		var target:Dynel = Character.GetClientCharacter();
		if (target) { DumpData(target); }
	}
	dv.SetValue(false);
}

function TrackTarget(dv:DistributedValue):Void {
	if (TrackingTarget) {
		clearInterval(TargetTrackingInterval);
		Dynels.UnregisterProperty(TrackingTargetID.m_Type, TrackingTargetID.m_Instance, _global.enums.Property.e_ObjPos);
		onEnterFrame = undefined;
		RemoveWaypoint(TrackingTargetID);
		TrackingTargetID = null;
		TrackingTarget = null;
		Log.Error("TDD", "Tracking Stopped");
	}
	if (dv.GetValue()) {
		var target:Dynel = _root.crosshaircontroller.m_Dynel;
		if (target) {
			Log.Error("TDD", "Tracking Started");
			TrackingTarget = target;
			TrackingTargetID = target.GetID();
			CreateWaypoint(target, target.GetName())
			onEnterFrame = UpdateWaypoints;
			Dynels.RegisterProperty(TrackingTargetID.m_Type, TrackingTargetID.m_Instance, _global.enums.Property.e_ObjPos);
			TargetTrackingInterval = setInterval(DumpData, IntervalLength.GetValue(), TrackingTarget);
			DumpData(target);
		} else { dv.SetValue(false); }
	} 
}

function TargetDespawned(type:Number, instance:Number):Void {
	if (TrackingTargetID.m_Type == type && TrackingTargetID.m_Instance == instance) {
		Log.Error("TDD", "Tracking Lost");
		TargetTrackingTrigger.SetValue(false);
	}
}

function NRMissionDump(dv:DistributedValue):Void {
	if (dv.GetValue()) { DumpNRMissions(); }
	dv.SetValue(false);
}

function DumpData(dynel:Dynel):Void {
	// Basic data
	Utils.PrintChatText("<font color='#FFB555'> TDD : </font>" + dynel.GetName());
	var pos:Vector3 = dynel.GetPosition(0);
	// Swizzled for map coords
	var locStr:String = ' zone="'+ dynel.GetPlayfieldID() + '" x="' + Math.round(pos.x) + '" y="'+ Math.round(pos.z) + '" z="' + Math.round(pos.y) + '"';
	Utils.PrintChatText(locStr);		
	Utils.PrintChatText("DynID: " + dynel.GetID().toString());
	
	// Type deduction
	var type:String = "DataDump"; // Generic tag name, if we can't deduce a more accurate one
	var extraProps:String = ""; // Extra properties to add to the returned xml, based on type deduction
	var subTags:Array = new Array();
	if (dynel.IsEnemy()) {
		// TODO: Are Champions the only hostile targets to get a special case?
		if (dynel.GetStat(2000560, 2)) {
			type = "Champ";
			extraProps = ' champID="' + dynel.GetStat(2000560, 2) + '"';
		} else if (dynel.GetName() == "Krampus") {
			type = "Krampus";
			subTags.push('<Name rdb="category=51000 id=' + dynel.GetStat(112, 2) + '" />');
			var dropID:Number;
			switch (dynel.GetPlayfieldID()) {
				case 3030: dropID = 8396923; break;
				case 3040: dropID = 8396925; break;
				case 3050: dropID = 8396935; break;
				case 3090: dropID = 8396934; break;
				case 3100: dropID = 8396936; break;
				case 3120: dropID = 8396924; break;
				case 3130: dropID = 8397024; break;
				case 3140: dropID = 8396926; break;
			}
			if (dropID) {
				subTags.push('<Note en="Drops: %1%" fmt="true">');
				subTags.push('<Param rdb="category=50200 id=' + dropID + '" />');
				subTags.push('</Note>');
			}
		}
	} else { if (dynel.IsMissionGiver()) {
		// Presuming that there are minimal hostile questgivers or vendors (there are a couple mobs that drop quests, but they can be handled manually)
		// What types do I want to catch for here?
		// Vendors, Missions, Lore (now there's a bunch of duplication), Anima Wells (have to be dead)
		// With most of those dealt with already, the next useful one would be Missions
		// Look in CrosshairController for filter logic
		type="QuestGiver";
		if (dynel.GetNametagCategory() == _global.Enums.NametagCategory.e_NameTagCategory_FriendlyNPC) {
			// NPC names seem to be pre-localized, rather than residing in memory as a remote format tag
			subTags.push('<Name rdb="id='+ dynel.GetStat(112, 2) + ' category=51000" />');
		} else {
			// Hopefully the rest are remote format tags
			var nameLookup:String = dynel.GetName();
			nameLookup = nameLookup.slice(nameLookup.indexOf("id="), nameLookup.indexOf(" key=")).split('"').join('');
			nameLookup = '<Name rdb="' + nameLookup + '" />';
			subTags.push(nameLookup);
		}
		var questList:QuestGiver = Quests.GetQuestGiver(dynel.GetID(), true);
		for (var i:Number = 0; i < questList.m_AvailableQuests.length; ++i) {
			var quest:Quest = questList.m_AvailableQuests[i];
			subTags.push(quest.m_MissionName + ' <Quest id="' + quest.m_ID + '" />');
		}
	} }
	var statDump = FullStatDump.GetValue() || SingleStatDump.GetValue();
	if (statDump) {
		Utils.PrintChatText("Stat dump");
		var value;
		// Note, not all of these stats exist on all types of objects, and some stats may only be accessible for self-inspection
		// Many of these are based off of _global.Enums.Stat values, while some attempts have been made to verify or explain them, some meanings may be uncertain
		var index:Object = new Object();
		index[1] = "Max HP";
		index[12] = "Model ID";
		index[23] = "FormatString ID"; // Less reliably available than 112
		index[27] = "Current HP";
		index[52] = "XP";
		index[54] = "Level";
		index[57] = "LastXP";
		index[59] = "Gender/Sex"; // 2 = male, 3 = female
		index[89] = "Creature Type"; // Mostly matches up with BreedEnum string file
		index[112] = "FormatString ID";
		index[179] = "NPC Flags";
		index[194] = "In Play"; // Should always be 1 for anything I can inspect?
		//index[359] = "??"; // Something to do with Anima charging buffs and applicable creatures? relevant values seem to be: 4080105, 4080104, 4079729, 4079727
		index[360] = "Scale?"; // Maybe something to do with the scale of the model
		index[506] = "Mana?"; // ?? 400?
		index[507] = "MaxMana?"; // ?? same as above
		index[512] = "Subscription Flags";
		index[589] = "Zone ID";
		//index[607] = "plid"; // Some sort of player ID? but not the actual Char# (which is used for dynel instances)
		index[864] = "Player Flags"; // Not actually observed
		index[1050] = "Cars Group?"; // ?? Some sort of Friend/Foe flag, "enemies"(and pets) = 3
		index[1102] = "Dynel Instance";
		index[1365] = "Extra Inventory Slots";
		index[1372] = "Rank Tag";
		index[1374] = "Override Cursor";
		index[1375] = "Dimension"; // Uncertain if current or origin
		index[1385] = "PvP Rating";
		index[1386] = "PvP Rating Diviation";
		index[1417] = "Inventory Upgrades";
		index[2000094] = "Faction"; // 1 = Dragon, 2 = Templar, 3 = Illuminati
		index[2000140] = "Rank";
		index[2000141] = "Weapon Type";
			// 524608 = Rifle, 262336 = Pistol, 5758114 = Shotgun,
			// 331776 = Blood, 274432 = Chaos, 397312 = Elemental,
			// 262177 = Blade, 262161 = Fist, 524291 = Hammer
		index[2000156] = "Evade?"; // Something to do with Evade? three copies, same value as the block labled Defense Rating?		
		index[2000157] = "Evade?";
		index[2000158] = "Evade?";
		index[2000192] = "Defense Rating?"; // Same value as "Evade"...
		index[2000193] = "Defense Rating?";
		index[2000194] = "Defense Rating?";
		index[2000201] = "Crit Chance"; // Four copies again... should pay attention if any of them differ
		index[2000202] = "Crit Chance";
		index[2000203] = "Crit Chance";
		index[2000204] = "Crit Chance";
		index[2000222] = "Crit Power";
		index[2000246] = "Weapon Power"; // Melee
		index[2000247] = "Weapon Power"; // Ranged
		index[2000254] = "Healing multiplier";
		index[2000266] = "Protection"; // "Death" protection
		index[2000268] = "Protection"; // "Fire" protection
		index[2000269] = "Protection"; // "Jinx" (Magic?) protection
		index[2000271] = "Protection"; // Physical Protection
		index[2000291] = "Attack Rating"; // Magic
		index[2000292] = "Attack Rating"; // Melee
		index[2000293] = "Attack Rating"; // Ranged
		index[2000314] = "Heal Rating"; // Heal
		index[2000362] = "Heal Rating"; // Leech
		index[2000376] = "Heal rating"; // Barrier
		index[2000406] = "Shield HP";
		index[2000411] = "Weapon Power"; // "Raid"?
		index[2000420] = "Power House?"; // ??
		index[2000425] = "Weapon Power"; // "Elemental"
		index[2000426] = "Weapon Power"; // "Jinx"
		index[2000427] = "Weapon Power"; // "Death"
		index[2000446] = "Max equipped weapons"; // Should be 2? or does it drop to 1 with certain items
		index[2000495] = "PvP Kills";
		index[2000558] = "Title ID";
		index[2000560] = "Unlockable Tag ID";
		index[2000607] = "IP";
		index[2000659] = "First Active Aegis"; // ?? Used for what? I've got a 7
		index[2000660] = "Second Active Aegis"; // ?? 10 here
		index[2000679] = "Nightmare Mob Flag";
		index[2000694] = "Achievement Points";
		index[2000697] = "Anima Energy"; // Ultimate ability? Not Essence (aka death tax)
		index[2000708] = "Trial days"; // ?? I've got a huge number here
		index[2000725] = "Blade XP";
		index[2000726] = "Hammer XP";
		index[2000727] = "Fist XP";
		index[2000728] = "Blood XP";		
		index[2000729] = "Chaos XP";
		index[2000730] = "Elemental XP";
		index[2000731] = "Shotgun XP";
		index[2000732] = "Pistol XP";
		index[2000733] = "Rifle XP";
		index[2000734] = "Whip XP"; // Unused, shouldn't show up
		index[2000735] = "Chainsaw XP"; // Same as whip
		index[2000736] = "Quantum XP"; // Same as whip
		index[2000737] = "Flamer XP"; // Same as whip
		index[2000738] = "Rocket XP"; // This one is used... sortof
		index[2000741] = "Character Class"; // From character creation?
		index[2000742] = "Blood healing debuff";
		index[2000744] = "Potion Count";
		index[2000747] = "Next AP (XP)";
		index[2000748] = "Next SP (XP)";
		index[2000764] = "Anima Allocation: Healing"; // DPS allocation is inferred
		index[2000765] = "Anima Allocation: Health";
		index[2000767] = "Maximum IP Reached";
		
		if (statDump === true) {					
			for (var i:Number = 0; i < 2500000; ++i) {
				value = dynel.GetStat(i, 2);
				if (value) { 
					switch (i) {
						case 89:
							Utils.PrintChatText(i + (index[i] ? (" (" + index[i] + ")") : "") + " : " + value + " (" + LDBFormat.LDBGetText(54000, value) + ")");
							break;
						default:
							Utils.PrintChatText(i + (index[i] ? (" (" + index[i] + ")") : "") + " : " + value);
					}
				}
			}
		} else {
			value = dynel.GetStat(statDump, 2);
			if (value) { 
				switch (statDump) {
					case 89:
						Utils.PrintChatText(statDump + (index[statDump] ? (" (" + index[statDump] + ")") : "") + " : " + value + " (" + LDBFormat.LDBGetText(54000, value) + ")");
						break;
					default:
						Utils.PrintChatText(statDump + (index[statDump] ? (" (" + index[statDump] + ")") : "") + " : " + value);
				}
			}
		}
	}
	if (dynel.IsMissionGiver() && MissionInfoDump.GetValue()) {
		var questList:QuestGiver = Quests.GetQuestGiver(dynel.GetID(), true);
		for (var i:Number = 0; i < questList.m_AvailableQuests.length; ++i) {
			var quest = questList.m_AvailableQuests[i];
			Utils.PrintChatText("Quest index " + i);
			for (var key:String in quest) {
				Utils.PrintChatText("  " + key + " : " + quest[key]);
			}
		}
	}
	// Cartographer (or near enough) formatted log output ready for extraction
	if (subTags.length == 0) {
		Log.Error("TDD", LDBFormat.Translate(dynel.GetName()) + " <" + type + extraProps + locStr + " />");
	} else {
		Log.Error("TDD", LDBFormat.Translate(dynel.GetName()) + " <" + type + extraProps + locStr + "> " +
				  subTags.join(" ") +
				  " </" + type + ">");
	}
}

function DumpNRMissions():Void {
	var compQuests:Array = Quests.GetAllCompletedQuests();
	Utils.PrintChatText("Dumping...: " + compQuests.length);
	Log.Error("TDD", "No-Repeat Quest List");
	for (var i = 0; i < compQuests.length; ++i) {
		var q:Quest = compQuests[i];
		if (!q.m_IsRepeatable) {
			Utils.PrintChatText("  " + q.m_MissionName + " (" + q.m_ID + ")");
			Log.Error("TDD", q.m_MissionName + " (" + q.m_ID + ")");
		}
	}
}

function CreateWaypoint(dynel:Dynel, targetName:String):Void {
	var waypoint:Waypoint = new Waypoint();
	waypoint.m_Id = dynel.GetID();
	waypoint.m_WaypointType = _global.Enums.WaypointType.e_RMWPScannerBlip;
	waypoint.m_WaypointState = _global.Enums.QuestWaypointState.e_WPStateActive;
	waypoint.m_Label = targetName;
	waypoint.m_IsScreenWaypoint = true;
	waypoint.m_IsStackingWaypoint = true;
	waypoint.m_Radius = 0;
	waypoint.m_Color = 0x000000;
	waypoint.m_WorldPosition = dynel.GetPosition(0);
	var scrPos:Point = dynel.GetScreenPosition();
	waypoint.m_ScreenPositionX = scrPos.x;
	waypoint.m_ScreenPositionY = scrPos.y;
	waypoint.m_CollisionOffsetX = 0;
	waypoint.m_CollisionOffsetY = 0;
	waypoint.m_DistanceToCam = dynel.GetCameraDistance(0);
	waypoint.m_MinViewDistance = 0;
	waypoint.m_MaxViewDistance = 90;

	WaypointSystem.m_CurrentPFInterface.m_Waypoints[waypoint.m_Id.toString()] = waypoint;
	WaypointSystem.m_CurrentPFInterface.SignalWaypointAdded.Emit(waypoint.m_Id);
}

function RemoveWaypoint(dynelID:ID32):Void {
	var key:String = dynelID.toString();
	if (WaypointSystem.m_CurrentPFInterface.m_Waypoints[key]) {
		delete WaypointSystem.m_CurrentPFInterface.m_Waypoints[key];
		WaypointSystem.m_CurrentPFInterface.SignalWaypointRemoved.Emit(dynelID);
	}
}

// Ugly, but I don't really see any alternative to doing a per/frame update
function UpdateWaypoints():Void {
	if (TrackingTarget) {
		var scrPos:Point = TrackingTarget.GetScreenPosition();
		var waypoint:CustomWaypoint = WaypointSystem.m_RenderedWaypoints[TrackingTarget.GetID().toString()];
		waypoint.m_Waypoint.m_ScreenPositionX = scrPos.x;
		waypoint.m_Waypoint.m_ScreenPositionY = scrPos.y;
		waypoint.m_Waypoint.m_DistanceToCam = TrackingTarget.GetCameraDistance(0);
		// Improve name display so that it doesn't trim long names and is readable while waypoint off the sides of the screen
		// Will still end up being cut off when near, but not over, the edges of the screen
		waypoint["i_NameText"].autoSize = "center";
		switch (waypoint.m_Direction) {
			case "left" : {
				waypoint["i_NameText"]._x = 0;
				break;
			}
			case "right" : {
				waypoint["i_NameText"]._x = -waypoint["i_NameText"].textWidth;
				break;
			}
		}
		waypoint.Update(Stage.visibleRect.width);
	}
}