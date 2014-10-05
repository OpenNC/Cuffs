////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - timer cuff                                 //
//                            version 3.980                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

string g_sSubMenu = "Timer"; // Name of the submenu
string g_sParentMenu = "Main"; // mname of the menu, where the menu plugs in
list g_lTimes;
integer g_iTimesLength;
integer g_iCurrentTime;
integer g_iOnTime;
integer g_iLastTime;
integer g_iFirstOnTime;
integer g_iFirstRealTime;
integer g_iLastRez;
integer n;//for loops
string g_sMessage;
integer MAX_TIME=0x7FFFFFFF;
integer ATTACHMENT_COMMAND = 602;
integer ATTACHMENT_FORWARD = 610;
//these can change
integer REAL_TIME=1;
integer REAL_TIME_EXACT=5;
integer ON_TIME=3;
integer ON_TIME_EXACT=7;
string g_sToyName = "cuffs";
integer g_iInterfaceChannel;
key g_kMenuID;
key g_kOnMenuID;
key g_kRealMenuID;
key g_kWearer; // key of the current wearer to reset only on owner changes
list g_lLocalButtons = ["realtime","online"]; // any local, not changing buttons which will be used in this plugin, leave emty or add buttons as you like
list g_lTimeButtons = ["clear","+00:01","+00:05","+00:30","+03:00","+24:00","-00:01","-00:05","-00:30","-03:00","-24:00"];
integer g_iOnRunning;
integer g_iOnSetTime;
integer g_iOnTimeUpAt;
integer g_iLastOnTime;
integer g_iClockTimeAtLastOnTime;
integer g_iRealRunning;
integer g_iRealSetTime;
integer g_iRealTimeUpAt;
integer g_iLastRealTime;
integer g_iClockTimeAtLastRealTime;
integer g_iUnlockCollar;
integer g_iCollarLocked;
integer g_iClearRLVRestions;
integer g_iUnleash;
integer g_iBoth;
integer g_iWhoCanChangeTime;
integer g_iWhoCanChangeLeash;
integer g_iWhoCanOtherSettings;
integer g_iClockTime;
integer g_iTimeChange;
integer g_iOnUpdate;
integer g_iRealUpdated;
integer g_iWhichMenu;
key g_kMenuWho;
list lButtons;
//OpenCollae MESSAGE MAP
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_WEARERLOCKEDOUT = 521;
integer NOTIFY = 550;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer TIMER_EVENT = -10000; // str = "start" or "end". For start, either "online" or "realtime".
integer WEARERLOCKOUT=620;
string UPMENU = "BACK";

string GetScriptID()
{
    // strip away "OpenNC - " leaving the script's individual name
    list parts = llParseString2List(llGetScriptName(), ["-"], []);
    return llStringTrim(llList2String(parts, 1), STRING_TRIM) + "_";
}

string PeelToken(string in, integer slot)
{
    integer i = llSubStringIndex(in, "_");
    if (!slot) return llGetSubString(in, 0, i);
    return llGetSubString(in, i + 1, -1);
}
/*
integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;
    if (iChan>0)
        iChan=iChan*(-1);
    if (iChan > -10000)
        iChan -= 30000;
    return iChan;
}
*/
/*
Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
        llOwnerSay(sMsg);
    else if (llGetAgentSize(kID) != ZERO_VECTOR)
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer)
            llOwnerSay(sMsg);
    }
    else // remote request
        llRegionSayTo(kID, GetOwnerChannel(g_kWearer, 1111), sMsg);
}
*/
integer StartsWith(string sHaystack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(sHaystack, llStringLength(sNeedle), -1) == sNeedle);
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
}

DoMenu(key keyID, integer iAuth)
{
    if (keyID)
    {
        // not needed we just want the false
    }
    else
        return;
    string sPrompt = "Pick an option.";
    list lMyButtons = g_lLocalButtons + lButtons;
    sPrompt += "\n Online timer - "+Int2Time(g_iOnSetTime);
    if (g_iOnRunning==1)
        sPrompt += "\n Online timer - "+Int2Time(g_iOnTimeUpAt-g_iOnTime)+" left";
    else
        sPrompt += "\n Online timer - not running";
    sPrompt += "\n Realtime timer - "+Int2Time(g_iRealSetTime);
    if (g_iRealRunning==1)
        sPrompt += "\n Realtime timer - "+Int2Time(g_iRealTimeUpAt-g_iCurrentTime)+" left";
    else
        sPrompt += "\n Realtime timer - not running";
    if (g_iBoth)
    {
        sPrompt += "\n When BOTH the online and realtime timer go off:";
        lMyButtons += ["(*)bothtime"];
    }
    else
    {
        sPrompt += "\n When EITHER the online or realtime timer go off:";
        lMyButtons += ["()bothtime"];
    }
    if (g_iRealRunning || g_iOnRunning)
        lMyButtons += ["stop"];
    else if (g_iRealSetTime || g_iOnSetTime)
        lMyButtons += ["start"];    
    if (g_iUnlockCollar)
    {
        sPrompt += "\n\t the " + g_sToyName + " WILL be unlocked";
        lMyButtons += ["(*)unlock"];
    }
    else
    {
        sPrompt += "\n\t the " + g_sToyName + " will NOT be unlocked";
        lMyButtons += ["()unlock"];
    }
    if (g_iUnleash)
    {
        sPrompt += "\n\t the " + g_sToyName + " WILL be unchained";
        lMyButtons += ["(*)unchained"];
    }
    else
    {
        sPrompt += "\n\t the " + g_sToyName + " will NOT be unchained";
        lMyButtons += ["()unchained"];
    }
    if (g_iClearRLVRestions)
    {
        sPrompt += "\n\t the RLV restions WILL be cleared";
        lMyButtons += ["(*)clearRLV"];
    }
    else
    {
        sPrompt += "\n\t the RLV restions will NOT be cleared";
        lMyButtons += ["()clearRLV"];
    }
    llListSort(g_lLocalButtons, 1, TRUE); // resort menu buttons alphabetical
    g_kMenuID = Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0, iAuth);
}

DoOnMenu(key keyID, integer iAuth)
{
    if (keyID == "") return;
        string sPrompt = "Pick an option.";
    sPrompt += "\n Online timer - "+Int2Time(g_iOnSetTime);
    if (g_iOnRunning)
        sPrompt += "\n Online timer - "+Int2Time(g_iOnTimeUpAt-g_iOnTime)+" left";
    else
        sPrompt += "\n Online timer - not running";
    g_kOnMenuID = Dialog(keyID, sPrompt, g_lTimeButtons, [UPMENU], 0, iAuth);
}

DoRealMenu(key keyID, integer iAuth)
{
    if (keyID == "") return;
    string sPrompt = "Pick an option.";
    //fill in your button list and additional prompt here
    sPrompt += "\n Realtime timer - " + Int2Time(g_iRealSetTime);
    if (g_iRealRunning)
        sPrompt += "\n Realtime timer - "+Int2Time(g_iRealTimeUpAt-g_iCurrentTime)+" left";
    else
        sPrompt += "\n Realtime timer - not running";
    g_kRealMenuID = Dialog(keyID, sPrompt, g_lTimeButtons, [UPMENU], 0, iAuth);
}

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

string Int2Time(integer sTime)
{
    if (sTime<0) sTime=0;
    integer iSecs=sTime%60;
    sTime = (sTime-iSecs)/60;
    integer iMins=sTime%60;
    sTime = (sTime-iMins)/60;
    integer iHours=sTime%24;
    integer iDays = (sTime-iHours)/24;
    //this is the only line that needs changing...
    return ( (string)iDays+" days "+
        llGetSubString("0"+(string)iHours,-2,-1) + ":"+
        llGetSubString("0"+(string)iMins,-2,-1) + ":"+
        llGetSubString("0"+(string)iSecs,-2,-1) );
}

TimerWhentOff()
{
    if(g_iBoth && (g_iOnRunning == 1 || g_iRealRunning == 1))
        return;
    llMessageLinked(LINK_SET, WEARERLOCKOUT, "off", "");
    g_iOnSetTime=g_iRealSetTime=0;
    g_iOnRunning=g_iRealRunning=0;
    g_iOnTimeUpAt=g_iRealTimeUpAt=0;
    g_iWhoCanChangeTime=504;
    if(g_iUnlockCollar)
        llMessageLinked(LINK_SET, COMMAND_OWNER, "unlock", g_kWearer);
    if(g_iClearRLVRestions)
    {
        llMessageLinked(LINK_SET, COMMAND_OWNER, "clear", g_kWearer);
        if(!g_iUnlockCollar && g_iCollarLocked)
        {
            llSleep(2);
            llMessageLinked(LINK_SET, COMMAND_OWNER, "lock", g_kWearer);
        }
    }
    if(g_iUnleash)
        llMessageLinked(LINK_SET, COMMAND_OWNER, "unleash", "");
    g_iUnlockCollar=g_iClearRLVRestions=g_iUnleash=0;
//    Notify(g_kWearer, "The timer has expired", TRUE);
    llMessageLinked(LINK_SET, NOTIFY, "The timer has expired |TRUE",g_kWearer);
    llMessageLinked(LINK_SET, TIMER_EVENT, "end", "");
}

TimerStart(integer perm)
{// do What has to be Done
    g_iWhoCanChangeTime = perm;
    if(g_iRealSetTime)
    {
        g_iRealTimeUpAt=g_iCurrentTime+g_iRealSetTime;
        llMessageLinked(LINK_SET, WEARERLOCKOUT, "on", "");
        llMessageLinked(LINK_SET, TIMER_EVENT, "start", "realtime");
        g_iRealRunning=1;
    }
    else
        g_iRealRunning=3;
    if(g_iOnSetTime)
    {
        g_iOnTimeUpAt=g_iOnTime+g_iOnSetTime;
        llMessageLinked(LINK_SET, WEARERLOCKOUT, "on", "");
        llMessageLinked(LINK_SET, TIMER_EVENT, "start", "online");
        g_iOnRunning=1;
    }
    else
        g_iOnRunning=3;
}

integer UserCommand(integer iNum, string sStr, key kID)
{
    if (iNum == COMMAND_EVERYONE) return TRUE;  // No command for people with no privilege in this plugin.
    else if (iNum > COMMAND_EVERYONE || iNum < COMMAND_OWNER) return FALSE; // sanity check
    //someone asked for our menu
    //give this plugin's menu to kID
    if (llToLower(sStr) == "timer" || sStr == "menu "+g_sSubMenu) DoMenu(kID, iNum);
    else if (sStr == "refreshmenu")
            {
                llSleep (0.1);
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
            }
    else if(llGetSubString(sStr, 0, 5) == "timer ")
    {
        string sMsg=llGetSubString(sStr, 6, -1);
        //we got a response for something we handle locally
        if (sMsg == "realtime") DoRealMenu(kID, iNum);
        else if (sMsg == "online") DoOnMenu(kID, iNum);
        else if (sMsg == "start")
        {
            TimerStart(iNum);
            if(kID != g_kWearer) DoMenu(kID, iNum);
        }
        else if (sMsg == "stop")
        {
            TimerWhentOff();
            DoMenu(kID, iNum);
        }
        else if (sMsg == "(*)bothtime")
        {
            g_iBoth = FALSE;
            DoMenu(kID, iNum);
        }
        else if (sMsg == "()bothtime")
        {
            g_iBoth = TRUE;
            DoMenu(kID, iNum);
        }
        else if(sMsg=="(*)unlock")
        {
            if (iNum == COMMAND_OWNER) g_iUnlockCollar=0;
            else
//                Notify(kID,"Only the owner can change if the " + g_sToyName + " unlocks when the timer runs out.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Only the owner can change if the " + g_sToyName + " unlocks when the timer runs out. |FALSE",kID);
            DoMenu(kID, iNum);
        }
        else if(sMsg=="()unlock")
        {
            if(iNum == COMMAND_OWNER) g_iUnlockCollar=1;
            else
                llMessageLinked(LINK_SET, NOTIFY, "Only the owner can change if the " + g_sToyName + " unlocks when the timer runs out. |FALSE",kID);
            DoMenu(kID, iNum);
         }
        else if(sMsg=="(*)clearRLV")
        {
            if(iNum == COMMAND_WEARER)
//                Notify(kID,"You cannot change if the RLV settings are cleared",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "You cannot change if the RLV settings are cleared |FALSE",kID);
            else g_iClearRLVRestions=0;
            DoMenu(kID, iNum);
        }
        else if(sMsg=="()clearRLV")
        {
            if(iNum == COMMAND_WEARER)
//                Notify(kID,"You cannot change if the RLV settings are cleared",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "You cannot change if the RLV settings are cleared |FALSE",kID);
            else g_iClearRLVRestions=1;
            DoMenu(kID, iNum);
        }
        else if(sMsg=="(*)unchained")
        {
            if(iNum <= g_iWhoCanChangeLeash) g_iUnleash=0;
            else
//                Notify(kID,"Only the someone who can leash the sub can change if the " + g_sToyName + " unchains when the timer runs out.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Only the someone who can leash the sub can change if the " + g_sToyName + " unchains when the timer runs out. |FALSE",kID);
            DoMenu(kID, iNum);
        }
        else if(sMsg=="()unchained")
        {
            if(iNum <= g_iWhoCanChangeLeash) g_iUnleash=1;
            else
//                Notify(kID,"Only the someone who can leash the sub can change if the " + g_sToyName + " unchains when the timer runs out.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Only the someone who can leash the sub can change if the " + g_sToyName + " unchains when the timer runs out. |FALSE",kID);
            DoMenu(kID, iNum);
        }
        else if(llGetSubString(sMsg, 0, 5) == "online")
            sMsg="on" + llStringTrim(llGetSubString(sMsg, 6, -1), STRING_TRIM_HEAD);
        if(llGetSubString(sMsg, 0, 1) == "on")
        {
            sMsg=llStringTrim(llGetSubString(sMsg, 2, -1), STRING_TRIM_HEAD);
            if (iNum <= g_iWhoCanChangeTime)
            {
                list lTimes = llParseString2List(llGetSubString(sMsg, 1, -1), [":"], []);
                if (sMsg == "clear")
                {
                    g_iOnSetTime=g_iOnTimeUpAt=0;
                    if(g_iOnRunning == 1)
                    {//unlock
                        g_iOnRunning=0;
                        TimerWhentOff();
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "+")
                {
                    g_iTimeChange=llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60;
                    g_iOnSetTime += g_iTimeChange;
                    if (g_iOnRunning==1)
                        g_iOnTimeUpAt += g_iTimeChange;
                    else if(g_iOnRunning==3)
                    {
                        g_iOnTimeUpAt=g_iOnTime+g_iOnSetTime;
                        g_iOnRunning=1;
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "-")
                {
                    g_iTimeChange=-(llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60);
                    g_iOnSetTime += g_iTimeChange;
                    if (g_iOnSetTime<0)
                        g_iOnSetTime=0;
                    if (g_iOnRunning==1)
                    {
                        g_iOnTimeUpAt += g_iTimeChange;
                        if (g_iOnTimeUpAt<=g_iOnTime)
                        {//unlock
                            g_iOnRunning=g_iOnSetTime=g_iOnTimeUpAt=0;
                            TimerWhentOff();
                        }
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "=")
                {
                    g_iTimeChange=llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60;
                    if (g_iTimeChange <= 0) return TRUE; // use clear.
                    g_iOnSetTime = g_iTimeChange;
                    if (g_iOnRunning==1)
                        g_iOnTimeUpAt = g_iOnTime + g_iTimeChange;
                    else if(g_iOnRunning==3)
                    {
                        g_iOnTimeUpAt=g_iOnTime + g_iTimeChange;
                        g_iOnRunning=1;
                    }
                }
                else
                    return TRUE;
            }
            DoOnMenu(kID, iNum);
        }
        else if(llGetSubString(sMsg, 0, 7) == "realtime")
            sMsg="real" + llStringTrim(llGetSubString(sMsg, 6, -1), STRING_TRIM_HEAD);
        if(llGetSubString(sMsg, 0, 3) == "real")
        {
            sMsg=llStringTrim(llGetSubString(sMsg, 4, -1), STRING_TRIM_HEAD);
            list lTimes = llParseString2List(llGetSubString(sMsg, 1, -1), [":"], []);
            if (iNum <= g_iWhoCanChangeTime)
            {
                if (sMsg == "clear")
                {
                    g_iRealSetTime=g_iRealTimeUpAt=0;
                    if(g_iRealRunning == 1)
                    {//unlock
                        g_iRealRunning=0;
                        TimerWhentOff();
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "+")
                {
                    g_iTimeChange=llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60;
                    g_iRealSetTime += g_iTimeChange;
                    if (g_iRealRunning==1) g_iRealTimeUpAt += g_iTimeChange;
                    else if(g_iRealRunning==3)
                    {
                        g_iRealTimeUpAt=g_iCurrentTime+g_iRealSetTime;
                        g_iRealRunning=1;
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "-")
                {
                    g_iTimeChange=-(llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60);
                    g_iRealSetTime += g_iTimeChange;
                    if (g_iRealSetTime<0) g_iRealSetTime=0;
                    if (g_iRealRunning==1)
                    {
                        g_iRealTimeUpAt += g_iTimeChange;
                        if (g_iRealTimeUpAt<=g_iCurrentTime)
                        {//unlock
                            g_iRealRunning=g_iRealSetTime=g_iRealTimeUpAt=0;
                            TimerWhentOff();
                        }
                    }
                }
                else if (llGetSubString(sMsg, 0, 0) == "=")
                {
                    g_iTimeChange=llList2Integer(lTimes,0)*60*60+llList2Integer(lTimes,1)*60;
                    if (g_iTimeChange <= 0) return TRUE; // Not handled.
                    g_iRealSetTime = g_iTimeChange;
                    if (g_iRealRunning==1) g_iRealTimeUpAt = g_iCurrentTime+g_iRealSetTime;
                    else if(g_iRealRunning==3)
                    {
                        g_iRealTimeUpAt=g_iCurrentTime+g_iRealSetTime;
                        g_iRealRunning=1;
                    }
                }
                else return TRUE;
            }
            DoRealMenu(kID, iNum);
        }
    }
    return TRUE;
}

default
{
    state_entry()
    {
        g_iLastTime=llGetUnixTime();
        llSetTimerEvent(1);
        g_kWearer = llGetOwner();
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0)
              g_iInterfaceChannel = -g_iInterfaceChannel;
        g_iFirstOnTime=MAX_TIME;
        g_iFirstRealTime=MAX_TIME;
        llRegionSay(g_iInterfaceChannel, "timer|sendtimers");
        llSleep(1.0);
        // send reequest to main menu and ask other menus if the wnt to register with us
        llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        //set settings
        g_iUnlockCollar=0;
        g_iClearRLVRestions=0;
        g_iUnleash=0;
        g_iBoth=0;
        g_iWhoCanChangeTime=504;
        g_iWhoCanChangeLeash=504;
        g_iWhoCanOtherSettings=504;
    }

    on_rez(integer iParam)
    {
        g_iLastTime=g_iLastRez=llGetUnixTime();
        llRegionSay(g_iInterfaceChannel, "timer|sendtimers");
        if (g_iRealRunning == 1 || g_iOnRunning == 1)
            llMessageLinked(LINK_SET, WEARERLOCKOUT, "on", "");
    }

    // listen for likend messages fromOC scripts
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        list info  = llParseString2List (sStr, ["|"], []);
        if(iNum==ATTACHMENT_FORWARD && llList2String(info, 0)=="timer")//request for us
        {
            string sCommand = llList2String(info, 1);
            integer type = llList2Integer(info, 2);
            if(sCommand=="settimer")
            {
                //should check values but I am not yet.
                if(type==REAL_TIME)
                {
                    integer newtime = llList2Integer(info, 3) +g_iCurrentTime;
                    g_lTimes=g_lTimes+[REAL_TIME,newtime];
                    if(g_iFirstRealTime>newtime)
                        g_iFirstRealTime=newtime;
                    g_sMessage="timer|timeis|"+(string)REAL_TIME+"|"+(string)g_iCurrentTime;
                }
                else if(type==REAL_TIME_EXACT)
                {
                    integer newtime = llList2Integer(info, 3);
                    g_lTimes=g_lTimes+[REAL_TIME,newtime];
                    if(g_iFirstRealTime>newtime)
                        g_iFirstRealTime=newtime;
                }
                else if(type==ON_TIME)
                {
                    integer newtime = llList2Integer(info, 3) +g_iOnTime;
                    g_lTimes=g_lTimes+[ON_TIME,newtime];
                    if(g_iFirstOnTime>newtime)
                        g_iFirstOnTime=newtime;
                    g_sMessage="timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
                }
                else if(type==ON_TIME_EXACT)
                {
                    integer newtime = llList2Integer(info, 3) +g_iOnTime;
                    g_lTimes=g_lTimes+[ON_TIME,newtime];
                    if(g_iFirstOnTime>newtime)
                        g_iFirstOnTime=newtime;
                }
            }
            else if(sCommand=="gettime")
            {
                if(type==REAL_TIME)
                    g_sMessage="timer|timeis|"+(string)REAL_TIME+"|"+(string)g_iCurrentTime;
                else if(type==ON_TIME)
                    g_sMessage="timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
            }
            else
                return; //message got sent to us or something went wrong
            if(iNum==ATTACHMENT_FORWARD)
                llRegionSay(g_iInterfaceChannel, g_sMessage);//need to wispear
        }
        else if(iNum == COMMAND_WEARERLOCKEDOUT && sStr == "menu")
        {
            if (g_iRealRunning || g_iRealRunning)
//                Notify(kID , "You are locked out of the " + g_sToyName + " until the timer expires", FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "You are locked out of the " + g_sToyName + " until the timer expires |FALSE",kID);
        }
        else if (iNum == LM_SETTING_DELETE)
        {
            if (sStr == "leash_leashedto") g_iWhoCanChangeLeash = 504;
            else if (sStr == "Global_locked") g_iCollarLocked=0;
        }
        else if (iNum == LM_SETTING_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string token = llList2String(lParams, 0);
            string value = llList2String(lParams, 1);
            if (token == "Global_locked" && (integer)value == 1) g_iCollarLocked = 1;
            else if (token == "leash_leashedto")
            {
                integer auth = (integer)llList2String(llParseString2List(value, [","], []), 1);
                if (auth < g_iWhoCanChangeLeash)
                {
                    g_iWhoCanChangeLeash = auth;
                    g_iUnleash = 0;
                }
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "Global_locked") g_iCollarLocked=(integer)sValue;
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            // our parent menu requested to receive buttons, so send ours
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == MENUNAME_RESPONSE)
            // a button is sned ot be added to a plugin
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string sButton = llList2String(lParts, 1);
                if (llListFindList(lButtons, [sButton]) == -1)
                    // if the button isnt in our benu yet, than we add it
                    lButtons = llListSort(lButtons + [sButton], 1, TRUE);
            }
        }
        else if (iNum == MENUNAME_REMOVE)
            // a button is sned ot be added to a plugin
        {
            integer iIndex;
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string sButton = llList2String(lParts, 1);
                iIndex = llListFindList(lButtons, [sButton]);
                if (iIndex != -1)
                    // if the button is in the menu, remove it
                    lButtons = llDeleteSubList(lButtons, iIndex, iIndex);
            }
        }
        else if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == DIALOG_RESPONSE)
        {
            if (llListFindList([g_kMenuID, g_kOnMenuID, g_kRealMenuID], [kID]) != -1)
            {//this is one of our menus
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (kID == g_kMenuID)
                {// request to change to parrent menu
                    if (sMsg == UPMENU)
                        //give kAv the parent menu
                        llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                    else if (llListFindList(lButtons, [sMsg]))
                        UserCommand(iAuth, "timer " + sMsg, kAv);
                    else if (~llListFindList(lButtons, [sMsg]))
                        //we got a command which another command pluged into our menu
                        llMessageLinked(LINK_SET, iAuth, "menu "+sMsg, kAv);
                }
                else if (kID == g_kOnMenuID)
                {
                    if (sMsg == UPMENU) DoMenu(kAv, iAuth);
                    else UserCommand(iAuth, "timer on"+sMsg, kAv);
                }
                else if (kID == g_kRealMenuID)
                {
                    if (sMsg == UPMENU) DoMenu(kAv, iAuth);
                    else UserCommand(iAuth, "timer real"+sMsg, kAv);
                }
            }
        }
    }

    timer()
    {
        g_iCurrentTime=llGetUnixTime();
        if (g_iCurrentTime<(g_iLastRez+60))
           return;
        if ((g_iCurrentTime-g_iLastTime)<60)
            g_iOnTime+=g_iCurrentTime-g_iLastTime;
        if(g_iOnTime>=g_iFirstOnTime)
        {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.
            g_sMessage="timer|timeis|"+(string)ON_TIME+"|"+(string)g_iOnTime;
            llRegionSay(g_iInterfaceChannel, g_sMessage);
            g_iFirstOnTime=MAX_TIME;
            g_iTimesLength=llGetListLength(g_lTimes);
            for(n = 0; n < g_iTimesLength; n = n + 2)// send notice and find the next time.
            {
                if(llList2Integer(g_lTimes, n)==ON_TIME)
                {
                    while(llList2Integer(g_lTimes, n+1)<=g_iOnTime&&llList2Integer(g_lTimes, n)==ON_TIME&&g_lTimes!=[])
                    {
                        g_lTimes=llDeleteSubList(g_lTimes, n, n+1);
                        g_iTimesLength=llGetListLength(g_lTimes);
                    }
                    if(llList2Integer(g_lTimes, n)==ON_TIME&&llList2Integer(g_lTimes, n+1)<g_iFirstOnTime)
                        g_iFirstOnTime=llList2Integer(g_lTimes, n+1);
                }
            }
        }
        if(g_iCurrentTime>=g_iFirstRealTime)
        {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.
            g_sMessage="timer|timeis|"+(string)REAL_TIME+"|"+(string)g_iCurrentTime;
            llRegionSay(g_iInterfaceChannel, g_sMessage);
            
            g_iFirstRealTime=MAX_TIME;
            g_iTimesLength=llGetListLength(g_lTimes);
            for(n = 0; n < g_iTimesLength; n = n + 2)// send notice and find the next time.
            {
                if(llList2Integer(g_lTimes, n)==REAL_TIME)
                {
                    while(llList2Integer(g_lTimes, n+1)<=g_iCurrentTime&&llList2Integer(g_lTimes, n)==REAL_TIME)
                    {
                        g_lTimes=llDeleteSubList(g_lTimes, n, n+1);
                        g_iTimesLength=llGetListLength(g_lTimes);
                    }
                    if(llList2Integer(g_lTimes, n)==REAL_TIME&&llList2Integer(g_lTimes, n+1)<g_iFirstRealTime)
                        g_iFirstRealTime=llList2Integer(g_lTimes, n+1);
                }
            }
        }
        if(g_iOnRunning == 1 && g_iOnTimeUpAt<=g_iOnTime)
        {
            g_iOnRunning = 0;
            TimerWhentOff();
        }
        if(g_iRealRunning == 1 && g_iRealTimeUpAt<=g_iCurrentTime)
        {
            g_iRealRunning = 0;
            TimerWhentOff();
        }
        g_iLastTime=g_iCurrentTime;
    }
}