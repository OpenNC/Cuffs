////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - rlvmain cuff                               //
//                            version 3.960                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

integer g_iRLVOn = FALSE;//set to TRUE if DB says user has turned RLV features on
integer g_iViewerCheck = FALSE;//set to TRUE if viewer is has responded to @versionnum message
integer g_iRLVNotify = FALSE;//if TRUE, ownersay on each RLV restriction
integer g_iListener;
float g_fVersionTimeOut = 30.0; //MD- changed from 60. 2 minute wait before finding RLV is off is too long.
integer g_iVersionChan = 293847;
integer g_iRlvVersion;
integer g_iCheckCount;//increment this each time we say @versionnum.  check it each time timer goes off in default state. give up if it's >= 2
string g_sRLVString = "RestrainedLife viewer v1.20";

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

string g_sParentMenu = "Main";
string g_sSubMenu = "RLV";
list g_lMenu;
key kMenuID;
integer RELAY_CHANNEL = -1812221819;
integer g_iVerbose;
//MESSAGE MAP
integer LM_CUFF_CMD = -551001;
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_EMPTY = 2004;//sent by httpdb script when a token has no value in the db
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..
integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
string UPMENU = "BACK";
string TURNON = "  ON";
string TURNOFF = " OFF";
string CLEAR = "CLEAR ALL";
string CTYPE = "cuffs";
key g_kWearer;
string g_sScript;
integer g_iLastDetach; //unix time of the last detach: used for checking if the detached time was small enough for not triggering the ping mechanism

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else
    {
        llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

CheckVersion(integer iSecond)
{
    if (g_iCheckCount && !iSecond) {
        return; //ongoing try
    }
    if (g_iVerbose)
    {
        Notify(g_kWearer, "Checking you out for hotness (and RLV), please wait a moment before use.", TRUE);
    }
    //open listener
    g_iListener = llListen(g_iVersionChan, "", g_kWearer, "");
    //start timer
    llSetTimerEvent(g_fVersionTimeOut);
    //do ownersay
    g_iCheckCount = !iSecond;
    llOwnerSay("@versionnum=" + (string)g_iVersionChan);
}

DoMenu(key kID, integer iAuth)
{
    list lButtons;
    if (g_iRLVOn)
    {
        lButtons += [TURNOFF, CLEAR] + llListSort(g_lMenu, 1, TRUE);
    }
    else
    {
        lButtons += [TURNON];
    }
    string sPrompt = "\n\n- Restrained Love Viewer Options -\n";
    if (g_iRlvVersion) sPrompt += "\n- Detected version of RLV API: "+(string)g_iRlvVersion;
    kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
} 

// http://wiki.secondlife.com/wiki/llSubStringIndex
integer StartsWith(string sHayStack, string sNeedle) 
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}
// Book keeping functions
list g_lOwners;
list g_lSources=[];
list g_lRestrictions=[];
list g_lOldRestrictions;
list g_lOldSources;
list g_lBaked=[];
key g_kSitter="";
key g_kSitTarget="";
integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

SendCommand(string sCmd)
{
    llOwnerSay("@"+sCmd);
    if (g_iRLVNotify)
    {
        Notify(g_kWearer, "Sent RLV Command: " + sCmd, TRUE);
    }
}

HandleCommand(key kID, string sCommand)
{
    string sStr=llToLower(sCommand);
    list lArgs = llParseString2List(sStr,["="],[]);
    string sCom = llList2String(lArgs,0);
    if (llGetSubString(sCom,-1,-1)==":") sCom=llGetSubString(sCom,0,-2);
    string sVal = llList2String(lArgs,1);
    if (sVal=="n"||sVal=="add") AddRestriction(kID,sCom);
    else if (sVal=="y"||sVal=="rem") RemRestriction(kID,sCom);
    else if (sCom=="clear") Release(kID,sVal);
    else
    {
        SendCommand(sStr);
        if (g_kSitter==""&&llGetSubString(sStr,0,3)=="sit:")
        {
            g_kSitter=kID;
            g_kSitTarget=(key)llGetSubString(sCom,4,-1);
        }
    }
}

AddRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    integer iRestr;
    // lock the cuffs for the first coming relay restriction (change the test if we decide that cuffs restrictions should un/lock)
    if (kID != "" && (g_lSources == [] || g_lSources == [""])) ApplyAdd("detach");
    if (iSource==-1)
    {
        g_lSources+=[kID];
        g_lRestrictions+=[sBehav];
        iRestr=-1;
        if (kID!="") llMessageLinked(LINK_SET, CMD_ADDSRC,"",kID);
    }
    else
    {
        list lSrcRestr = llParseString2List(llList2String(g_lRestrictions,iSource),["§"],[]);
        iRestr=llListFindList(lSrcRestr, [sBehav]);
        if (iRestr==-1)
        {
            g_lRestrictions=llListReplaceList(g_lRestrictions,[llDumpList2String(lSrcRestr+[sBehav],"§")],iSource, iSource);
        }
    }
    if (iRestr==-1)
    {
        ApplyAdd(sBehav);
        if (sBehav=="unsit")
        {
            g_kSitTarget = llList2Key(llGetObjectDetails(g_kWearer, [OBJECT_ROOT]), 0);
            g_kSitter=kID;
        }
    }
}

ApplyAdd (string sBehav)
{
    integer iRestr=llListFindList(g_lBaked, [sBehav]);
    if (iRestr==-1)
    {
        g_lBaked+=[sBehav];
        SendCommand(sBehav+"=n");
    }
}

RemRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    integer iRestr;
    if (iSource!=-1)
    {
        list lSrcRestr = llParseString2List(llList2String(g_lRestrictions,iSource),["§"],[]);
        iRestr=llListFindList(lSrcRestr,[sBehav]);
        if (iRestr!=-1)
        {
            if (llGetListLength(lSrcRestr)==1)
            {
                g_lRestrictions=llDeleteSubList(g_lRestrictions,iSource, iSource);
                g_lSources=llDeleteSubList(g_lSources,iSource, iSource);
                if (kID!="") llMessageLinked(LINK_SET, CMD_REMSRC,"",kID);
            }
            else
            {
                lSrcRestr=llDeleteSubList(lSrcRestr,iRestr,iRestr);
                g_lRestrictions=llListReplaceList(g_lRestrictions,[llDumpList2String(lSrcRestr,"§")] ,iSource,iSource);
            }
            if (sBehav=="unsit"&&g_kSitter==kID)
            {
                g_kSitter="";
                g_kSitTarget="";

            }
            ApplyRem(sBehav);
        }
    }
    // unlock the cuffs for the last going relay restriction (change the test if we decide that cuffs restrictions should un/lock)
    if (kID != "" && (g_lSources == [] || g_lSources == [""])) ApplyRem("detach");
}

ApplyRem(string sBehav)
{
    integer iRestr=llListFindList(g_lBaked, [sBehav]);
    if (iRestr!=-1)
    {
        integer i;
        integer iFound=FALSE;
        for (i=0;i<=llGetListLength(g_lRestrictions);i++)
        {
            list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,i),["§"],[]);
            if (llListFindList(lSrcRestr, [sBehav])!=-1) iFound=TRUE;
        }
        if (!iFound)
        {
            g_lBaked=llDeleteSubList(g_lBaked,iRestr,iRestr);
            SendCommand(sBehav+"=y");
        }
    }
}

Release(key kID, string sPattern)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    if (iSource!=-1) {
        list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,iSource),["§"],[]);
        integer i;
        if (sPattern!="") 
        {
            for (i=0;i<=llGetListLength(lSrcRestr);i++) 
            {
                string  sBehav=llList2String(lSrcRestr,i);
                if (llSubStringIndex(sBehav,sPattern)!=-1) 
                {
                    RemRestriction(kID,sBehav);
                }
            }
        } 
        else 
        {
            g_lRestrictions=llDeleteSubList(g_lRestrictions,iSource, iSource);
            g_lSources=llDeleteSubList(g_lSources,iSource, iSource);
            llMessageLinked(LINK_SET, CMD_REMSRC,"",kID);
            for (i=0;i<=llGetListLength(lSrcRestr);i++) 
            {
                string  sBehav=llList2String(lSrcRestr,i);
                ApplyRem(sBehav);
                if (sBehav=="unsit"&&g_kSitter==kID) 
                {
                    g_kSitter="";
                    g_kSitTarget="";
                }
            }
            if (g_lSources == [] || g_lSources == [""]) {
                ApplyRem("detach"); 
            }
        }
    }
}

SafeWord(integer iCollarToo) 
{
    SendCommand("clear");
    g_lBaked=[];
    g_lSources=[];
    g_lRestrictions=[];
    integer i;
    if (!iCollarToo) {
        llMessageLinked(LINK_SET,RLV_REFRESH,"","");
    }
}
// End of book keeping functions
integer UserCommand(integer iNum, string sStr, key kID)
{
    if (iNum == COMMAND_EVERYONE) return TRUE;  // No command for people with no privilege in this plugin.
    else if (iNum > COMMAND_EVERYONE || iNum < COMMAND_OWNER) return FALSE; // sanity check
    list lParams = llParseString2List(sStr, [" "], []);
    string sCmd = llList2String(lParams, 0);
    string sValue = llToLower(llList2String(lParams, 1));
    list lParams1 = llParseString2List(sStr, [":"], []);
    string sCmd1 = llList2String(lParams1, 1);
    if (sStr == llToLower(g_sSubMenu) || (sCmd == "menu" && llToUpper(sValue) == g_sSubMenu))
    { //someone clicked "RLV" on the main menu.  Give them our menu now
        DoMenu(kID, iNum);
    }
    else if (sStr == "refreshmenu")
    {
        llSleep (0.1);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
    }
    else if ((sCmd1 == "rlv=on") || (sStr == "rlvon"))
    {
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "on=1", "");
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvon","");
        g_iRLVOn = TRUE;
        g_iVerbose = TRUE;
        if (TRUE) state default;
    }
    else if (StartsWith(sStr, "rlvnotify"))
    {
        string sOnOff = llList2String(llParseString2List(sStr, [" "], []), 1);
        if (sOnOff == "on")
        {
            g_iRLVNotify = TRUE;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "notify=1", "");
        }
        else if (sOnOff == "off")
        {
            g_iRLVNotify = FALSE;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "notify=0", "");
        }
    }
    else if (!g_iRLVOn || !g_iViewerCheck) return TRUE;
    // commands after this should only work when RLV is enabled and verified
    if (sStr == "clear")
    {
        if (iNum == COMMAND_WEARER)
        {
            Notify(g_kWearer,"Sorry, but the sub cannot clear RLV settings.",TRUE);
        }
        else
        {
            llMessageLinked(LINK_SET, RLV_CLEAR, "", "");
            SafeWord(TRUE);
        }
    }
    else if ((sCmd1 == "rlv=on") || (sStr == "rlvon"))
    {
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "on=1", "");
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvon","");
        g_iRLVOn = TRUE;
        g_iVerbose = TRUE;
        if (TRUE) state default;
    }
    else if ((sCmd1 == "rlv=off") | (sStr == "rlvoff"))
    {
        if (iNum == COMMAND_OWNER)
        {
            g_iRLVOn = FALSE;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "on=0", "");
            SafeWord(TRUE);
            llMessageLinked(LINK_SET, RLV_OFF, "", "");
            llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvoff","");
        }
        else Notify(kID, "Sorry, only owner may disable Restrained Love functions", FALSE);
    }
    else if (sStr=="showrestrictions")
    {
        string sOut="You are being restricted by the following object";
        if (llGetListLength(g_lSources)==2) sOut+=":";
        else sOut+="s:";
        integer i;
        for (i=0;i<llGetListLength(g_lSources);i++)
            if (llList2String(g_lSources,i)!="") sOut+="\n"+llKey2Name((key)llList2String(g_lSources,i))+" ("+llList2String(g_lSources,i)+"): "+llList2String(g_lRestrictions,i);
        else sOut+="\nThis " + CTYPE + ": "+llList2String(g_lRestrictions,i);
        Notify(kID,sOut,FALSE);
    }
    return TRUE;
}

default
{
    state_entry()
    {
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer = llGetOwner();
        //request setting from DB
        llSleep(1.0);
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sScript + "on", "");
        // Ensure that menu script knows we're here.
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        if (g_iRLVOn)
        {
            CheckVersion(FALSE);//NG hack to force it to check RLV
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == LM_SETTING_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if(sToken == "auth_owner" && llStringLength(sValue) > 0)
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if(sToken == "auth_owner" && llStringLength(sValue) > 0)
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
            else if (sToken == "Global_CType") CTYPE = sValue;
            else if (llGetSubString(sToken, 0, i) == g_sScript)
            {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "on")
                {
                    if (sValue == "unset") CheckVersion(FALSE);
                    else if (!(integer)sValue)
                    {
                        state checked;
                        llMessageLinked(LINK_SET, RLV_OFF, "", "");
                    }
                    else
                    {
                        g_iRLVOn = TRUE;
                        llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvon","");//send it to slave cuffs
                        //check viewer version
                        CheckVersion(FALSE);
                    }
                }
                else if (sToken == "notify") g_iRLVNotify = (integer)sValue;
            }
        }
        else if ((iNum == LM_SETTING_EMPTY && sStr == g_sScript + "on"))
        {
            CheckVersion(FALSE);
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER && sStr == "menu "+g_sSubMenu)
        {   //someone clicked "RLV" on the main menu.  Tell them we're not ready yet.
            Notify(kID, "Still querying for viewer version.  Please try again in a minute.", FALSE);
        }
    }

    listen(integer iChan, string sName, key kID, string sMsg)
    {
        if (iChan == g_iVersionChan)
        {
            llListenRemove(g_iListener);
            llSetTimerEvent(0.0);
            g_iCheckCount = 0;
            //send the version to rlv plugins
            g_iRlvVersion = (integer) llGetSubString(sMsg, 0, 2);
            llMessageLinked(LINK_SET, RLV_VERSION, (string) g_iRlvVersion, "");
            g_iRLVOn = TRUE;
            llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvon","");
            if (g_iRLVNotify)
            {
                llOwnerSay("Restrained Love functions enabled. " + sMsg + " detected.");
            }
            g_iViewerCheck = TRUE;
            llMessageLinked(LINK_SET, RLV_ON, "", "");
            state checked;
        }
    }

    timer() {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        if (g_iCheckCount) 
        {   
// the viewer hasn't responded after 30 seconds, but maybe it was still logging in when we did @versionnum give it one more  chance
            CheckVersion(TRUE);
        }
        else 
        { //we've given the viewer a full 60 seconds
            g_iViewerCheck = FALSE;
            g_iRLVOn = FALSE;
            llMessageLinked(LINK_SET, RLV_OFF, "", "");
            Notify(g_kWearer,"Could not detect Restrained Love Viewer.  Restrained Love functions disabled.",TRUE);
            if (llGetListLength(g_lRestrictions) > 0 && llGetListLength(g_lOwners) > 0) {
                string sMsg = llKey2Name(g_kWearer)+" appears to have logged in without using the Restrained Love Viewer.  Their Restrained Love functions have been disabled.";
                integer i_OwnerCount=llGetListLength(g_lOwners);
                if (i_OwnerCount == 2) 
                { // only 1 owner
                    Notify(g_kWearer,"Your owner has been notified.",FALSE);
                    Notify(llList2Key(g_lOwners,0), sMsg, FALSE);
                } 
                else 
                {
                    Notify(g_kWearer,"Your owners have been notified.",FALSE);
                    integer i;
                    for(i=0; i < i_OwnerCount; i+=2) 
                    {
                        Notify(llList2Key(g_lOwners,i), sMsg, FALSE);
                    }
                }
            }
            state checked;
        }
    }

    changed(integer change) 
    {
        if (change & CHANGED_OWNER) 
        {
            llResetScript();
        }
    }
}

state checked 
{
    on_rez(integer iParam) 
    {
        //reset only if the detach delay was long enough (it could be an
        //automatic reattach)
        if (llGetUnixTime()-g_iLastDetach > 15) 
        {
            state default;
        } 
        else 
        {
            integer i;
            for (i = 0; i < llGetListLength(g_lBaked); i++)
            {
                SendCommand(llList2String(g_lBaked,i)+"=n");
            }
            llSleep(2);
            // wake up other plugins anyway (tell them that RLV is still
            // active, as it is likely they did reset themselves
            llMessageLinked(LINK_SET, RLV_REFRESH, "", "");         
        }
    }

    attach(key kID)
    {
        if (kID == "") g_iLastDetach = llGetUnixTime(); //remember when the cuffs was detached last
    }

    state_entry()
    {
        g_lMenu = [];
        if (g_iRLVOn && g_iViewerCheck)//we don't need this since cuffs don't have submenu for RLV
        {   //ask RLV plugins to tell us about their rlv submenus
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
            //tell rlv plugins to reinstate restrictions  (and wake up the relay listener... so that it can at least hear !pong's!
            llMessageLinked(LINK_SET, RLV_REFRESH, "", "");
            llSleep(5); //Make sure the relay is ready before pinging
            //ping inworld object so that they reinstate their restrictions
            integer i;
            for (i=0;i<llGetListLength(g_lSources);i++) 
            {
                if ((key)llList2String(g_lSources,i)) 
                {
                    llShout(RELAY_CHANNEL,"ping,"+llList2String(g_lSources,i)+",ping,ping");
                }
            }
            g_lOldRestrictions=g_lRestrictions;
            g_lOldSources=g_lSources;
            g_lRestrictions=[];
            g_lSources=[];
            g_lBaked=[];
            llSetTimerEvent(2);
        }
        // Ensure that menu script knows we're here.
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) 
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) 
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        }
        else if (iNum == COMMAND_NOAUTH) return;
        else if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == kMenuID)
            {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMsg == TURNON)
                {
                    UserCommand(iAuth, "rlvon", kAv);
                }
                else if (sMsg == TURNOFF)
                {
                    UserCommand(iAuth, "rlvoff", kAv);
                    DoMenu(kAv, iAuth);
                }
                else if (sMsg == CLEAR)
                {
                    UserCommand(iAuth, "clear", kAv);
                    DoMenu(kAv, iAuth);
                }
                else if (sMsg == UPMENU)
                {
                    llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                }
                else if (llListFindList(g_lMenu, [sMsg]) != -1 && g_iRLVOn)
                {
                    llMessageLinked(LINK_SET, iAuth, "menu " + sMsg, kAv);
                }
            }
        }
        //these are things we only do if RLV is ready to go
        if (g_iRLVOn && g_iViewerCheck)
        {   //if RLV is off, don't even respond to RLV submenu events
            if (iNum == MENUNAME_RESPONSE)
            {    //sStr will be in form of "parentmenu|menuname"
                list lParams = llParseString2List(sStr, ["|"], []);
                string sThisParent = llList2String(lParams, 0);
                string sChild = llList2String(lParams, 1);
                if (sThisParent == g_sSubMenu)
                {     //add this str to our menu buttons
                    if (llListFindList(g_lMenu, [sChild]) == -1)
                    {
                        g_lMenu += [sChild];
                    }
                }
            }
            else if (iNum == MENUNAME_REMOVE)
            {    //sStr will be in form of "parentmenu|menuname"
                list lParams = llParseString2List(sStr, ["|"], []);
                string sThisParent = llList2String(lParams, 0);
                string sChild = llList2String(lParams, 1);
                if (sThisParent == g_sSubMenu)
                {
                    integer iIndex = llListFindList(g_lMenu, [sChild]);
                    if (iIndex != -1)
                    {
                        g_lMenu = llDeleteSubList(g_lMenu, iIndex, iIndex);
                    }
                }
            }
            else if (iNum == RLV_CMD)
            {
                list sCommands=llParseString2List(sStr,[","],[]);
                integer i;
                for (i=0;i<llGetListLength(sCommands);i++) HandleCommand(kID,llList2String(sCommands,i));
            }
            else if (iNum == COMMAND_RLV_RELAY)
            {
                if (llGetSubString(sStr,-43,-1)!=","+(string)g_kWearer+",!pong") return;
                if (kID==g_kSitter)
                {
                    SendCommand("sit:"+(string)g_kSitTarget+"=force");
                }
                integer iSourceNum=llListFindList(g_lOldSources, [kID]);
                if (iSourceNum == -1) return; // Unknown source decided to answer to this ping while uninvited. Better ignore it.
                integer j;
                list iRestr=llParseString2List(llList2String(g_lOldRestrictions,iSourceNum),["/"],[]);
                for (j=0;j<llGetListLength(iRestr);j++) AddRestriction(kID,llList2String(iRestr,j));
            }
            else if (iNum == COMMAND_SAFEWORD)
            {// safeWord used, clear rlv settings
                llMessageLinked(LINK_SET, RLV_CLEAR, "", "");
                SafeWord(TRUE);
            }
            else if (iNum == LM_SETTING_SAVE)
            {
                list lParams = llParseString2List(sStr, ["="], []);
                string sToken = llList2String(lParams, 0);
                string sValue = llList2String(lParams, 1);
                if(sToken == "auth_owner" && llStringLength(sValue) > 0)
                {
                    g_lOwners = llParseString2List(sValue, [","], []);
                }
            }
            else if (iNum == LM_SETTING_RESPONSE)
            {
                list lParams = llParseString2List(sStr, ["="], []);
                string sToken = llList2String(lParams, 0);
                string sValue = llList2String(lParams, 1);
                integer i = llSubStringIndex(sToken, "_");
                if(sToken == "auth_owner" && llStringLength(sValue) > 0)
                {
                    g_lOwners = llParseString2List(sValue, [","], []);
                }
                else if (llGetSubString(sToken, 0, i) == g_sScript)
                {
                    sToken = llGetSubString(sToken, i + 1, -1);
                    if (sToken == "notify") g_iRLVNotify = (integer)sValue;
                }
            }
            else if (iNum==COMMAND_RELAY_SAFEWORD)
            {
                SafeWord(FALSE);
            }
        }
    }

    timer()
    {
        llSetTimerEvent(0.0);
        g_lOldSources=[];
        g_lOldRestrictions=[];
    }
    
    changed(integer change) 
    {
        if (change & CHANGED_OWNER) 
        {
            llResetScript();
        }
    }
}
