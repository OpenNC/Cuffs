////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - lock cuff                                  //
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

list g_lOwners;
string g_sParentMenu = "Main";
string g_sRequestType; //may be "owner" or "secowner" or "rem secowner"
key g_kHTTPID;
integer g_iListenChan = 802930;//just something i randomly chose
integer g_iListener;
integer g_iLocked = FALSE;
string g_sLockPrimName="Lock"; // Description for lock elements to recognize them //EB //SA: to be removed eventually (kept for compatibility)
string g_sOpenLockPrimName="OpenLock"; // Prim description of elements that should be shown when unlocked
string g_sClosedLockPrimName="ClosedLock"; // Prim description of elements that should be shown when locked
list g_lClosedLockElements; //to store the locks prim to hide or show //EB
list g_lOpenLockElements; //to store the locks prim to hide or show //EB
string LOCK = "LOCK";
string UNLOCK = "UNLOCK";
//MESSAGE MAP
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer NOTIFY = 550;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer LM_CUFF_CMD = -551001;//send a cuff command
//added to prevent altime attach messages
integer g_bDetached = FALSE;
key g_kWearer;
string CTYPE = "cuffs";
/*
Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
        llOwnerSay(sMsg);
    else
    {
        llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer)
            llOwnerSay(sMsg);
    }
}
*/
NotifyOwners(string sMsg)
{
    integer n;
    integer stop = llGetListLength(g_lOwners);
    for (n = 0; n < stop; n += 2)
    {
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
            return;
        }
        else
//            Notify((key)llList2String(g_lOwners, n), sMsg, FALSE);
            llMessageLinked(LINK_SET, NOTIFY, sMsg + " |FALSE",(key)llList2String(g_lOwners, n));
    }
}

string GetPSTDate()
{ //Convert the date from UTC to PST if GMT time is less than 8 hours after midnight (and therefore tomorow's date).
    string DateUTC = llGetDate();
    if (llGetGMTclock() < 28800) // that's 28800 seconds, a.k.a. 8 hours.
    {
        list DateList = llParseString2List(DateUTC, ["-", "-"], []);
        integer year = llList2Integer(DateList, 0);
        integer month = llList2Integer(DateList, 1);
        integer day = llList2Integer(DateList, 2);
        day = day - 1;
        return (string)year + "-" + (string)month + "-" + (string)day;
    }
    return llGetDate();
}

string GetTimestamp() // Return a string of the date and time
{
    integer t = (integer)llGetWallclock(); // seconds since midnight
    return GetPSTDate() + " " + (string)(t / 3600) + ":" + PadNum((t % 3600) / 60) + ":" + PadNum(t % 60);
}

string PadNum(integer value)
{
    if(value < 10)
    {
        return "0" + (string)value;
    }
    return (string)value;
}

BuildLockElementList()//EB
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];
    for (n = 2; n <= iLinkCount; n++)//root prim is 1, so start at 2
    { // read description
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        // check inf name is lock name
        if (llList2String(lParams, 0)==g_sLockPrimName || llList2String(lParams, 0)==g_sClosedLockPrimName)  // if so store the number of the prim
            g_lClosedLockElements += [n];
        else if (llList2String(lParams, 0)==g_sOpenLockPrimName)  // if so store the number of the prim
            g_lOpenLockElements += [n];
    }
}

SetLockElementAlpha() //EB
{//loop through stored links, setting alpha if element type is lock
    integer n;
    float fAlpha;
    if (g_iLocked) fAlpha = 1.0; else fAlpha = 0.0;
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (n = 0; n < iLinkElements; n++)
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,n), 1.0 - fAlpha, ALL_SIDES);
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (n = 0; n < iLinkElements; n++)
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,n), fAlpha, ALL_SIDES);
}

Lock()
{
    g_iLocked = TRUE;
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "Global_locked=1", "");
    llMessageLinked(LINK_SET, RLV_CMD, "detach=n", "");
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, "");
    llPlaySound("caa78697-8493-ead3-4737-76dcc926df30", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + LOCK, "");
    SetLockElementAlpha();//EB
    llMessageLinked(LINK_SET, LM_CUFF_CMD, "Lock=on", "");
}

Unlock()
{
    g_iLocked = FALSE;
    llMessageLinked(LINK_SET, LM_SETTING_DELETE, "Global_locked", "");
    llMessageLinked(LINK_SET, RLV_CMD, "detach=y", "");
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, "");
    llPlaySound("ff09cab4-3358-326e-6426-ec8d3cd3b98e", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + UNLOCK, "");
    SetLockElementAlpha(); //EB
    llMessageLinked(LINK_SET, LM_CUFF_CMD, "Lock=off", "");
}

default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        g_kWearer = llGetOwner();
        g_iListenChan = -1 - llRound(llFrand(9999999.0));
        BuildLockElementList();//EB
        SetLockElementAlpha(); //EB
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum >= COMMAND_OWNER && iNum <=COMMAND_WEARER)
        {
            if (sStr == "settings")
            {
                if (g_iLocked)// Notify(kID, "Locked.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Locked |FALSE",kID);
                else //Notify(kID, "Unlocked.", FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Unlocked |FALSE",kID);
            }
            else if (sStr == "refreshmenu")
            {
                llSleep (0.1);
                if (g_iLocked)
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, "");
                else
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, "");
            }
            else if (sStr == "lock" || (!g_iLocked && sStr == "togglelock"))
            {
                if (iNum == COMMAND_OWNER || kID == g_kWearer )
                {   //primary owners and wearer can lock and unlock. no one else
                    Lock();
//                    Notify(kID, "Locked.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Locked |FALSE",kID);
                    if (kID!=g_kWearer) llOwnerSay("Your " + CTYPE + " have been locked.");
                }
                else //Notify(kID, "Sorry, only primary owners and wearer can lock the " + CTYPE + ".", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Sorry, only primary owners and wearer can lock the " + CTYPE + ". |FALSE",kID);
            }
            else if (sStr == "runaway" || sStr == "unlock" || (g_iLocked && sStr == "togglelock"))
            {
                if (iNum == COMMAND_OWNER)
                {  //primary owners can lock and unlock. no one else
                    Unlock();
//                    Notify(kID, "Unlocked.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Unlocked |FALSE",kID);
                    if (kID!=g_kWearer) llOwnerSay("Your " + CTYPE + " have been unlocked.");
                }
                else //Notify(kID, "Sorry, only primary owners can unlock the " + CTYPE + ".", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Sorry, only primary owners and wearer can lock the " + CTYPE + ". |FALSE",kID);
            }
            else if (sStr == "menu " + LOCK)
            {
                if (iNum == COMMAND_OWNER || kID == g_kWearer )
                {   //primary owners and wearer can lock. no one else
                    Lock();
//                    Notify(kID, "Locked.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Locked. |FALSE",kID);
                    if (kID!=g_kWearer) llOwnerSay("Your " + CTYPE + " has been locked.");
                }
                else //Notify(kID, "Sorry, only primary owners and wearer can lock the " + CTYPE + ".", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Sorry, only primary owners and wearer can lock the " + CTYPE + ". |FALSE",kID);
                llMessageLinked(LINK_SET, iNum, "menu " + g_sParentMenu, kID);
            }
            else if (sStr == "menu " + UNLOCK)
            {
                if (iNum == COMMAND_OWNER)
                {  //primary owners can unlock. no one else
                    Unlock();
//                    Notify(kID, "Unlocked.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Unlocked. |FALSE",kID);
                    if (kID!=g_kWearer) llOwnerSay("Your " + CTYPE + " has been unlocked.");
                }
                else //Notify(kID, "Sorry, only primary owners can unlock the " + CTYPE + ".", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Sorry, only primary owners and wearer can unlock the " + CTYPE + ". |FALSE",kID);
                llMessageLinked(LINK_SET, iNum, "menu " + g_sParentMenu, kID);
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "Global_locked")
            {
                g_iLocked = (integer)sValue;
                if (g_iLocked)
                {
                    llMessageLinked(LINK_SET, RLV_CMD, "detach=n", "");
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, "");
                    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + LOCK, "");
                }
                else
                {
                    llMessageLinked(LINK_SET, RLV_CMD, "detach=y", "");
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, "");
                    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + UNLOCK, "");
                }
                SetLockElementAlpha(); //EB
            }
            else if (sToken == "Global_CType") CTYPE = sValue;
            else if (sToken == "auth_owner")
                g_lOwners = llParseString2List(sValue, [","], []);
        }
        else if (iNum == LM_SETTING_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "auth_owner")
                g_lOwners = llParseString2List(sValue, [","], []);
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            if (g_iLocked)
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, "");
            else
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, "");
        }
        else if (iNum == RLV_REFRESH)
        {
            if (g_iLocked)
                llMessageLinked(LINK_SET, RLV_CMD, "detach=n", "");
            else
                llMessageLinked(LINK_SET, RLV_CMD, "detach=y", "");
        }
        else if (iNum == RLV_CLEAR)
        {
            if (g_iLocked)
                llMessageLinked(LINK_SET, RLV_CMD, "detach=n", "");
            else
                llMessageLinked(LINK_SET, RLV_CMD, "detach=y", "");
        }
    }
    attach(key kID)
    {
        if (g_iLocked)
        {
            if(kID == "")
            {
                g_bDetached = TRUE;
                NotifyOwners(llKey2Name(g_kWearer) + " has detached me while locked at " + GetTimestamp() + "!");
            }
            else if(g_bDetached)
            {
                NotifyOwners(llKey2Name(g_kWearer) + " has re-atached me at " + GetTimestamp() + "!");
                g_bDetached = FALSE;
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
            llResetScript();
    }

    on_rez(integer start_param)
    {
        if (g_kWearer != llGetOwner())
            llResetScript();
    }
}