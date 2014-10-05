////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - auth                                       //
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

key g_kWearer;
list g_lOwners;//strided list in form key,name
key g_kGroup = "";
string g_sGroupName;
integer g_iGroupEnabled = FALSE;
list g_lSecOwners;//strided list in the form key,name
list g_lBlackList;//list of blacklisted UUID
string g_sTmpName; //used temporarily to store new owner or secowner name while retrieving key
string  g_sWikiURL = "http://www.opencollar.at/user-guide.html";
string g_sParentMenu = "Main";
string g_sSubMenu = "Access";
string g_sRequestType; //may be "owner" or "secowner" or "remsecowner"
key g_kHTTPID;
key g_kGroupHTTPID;
string g_sOwnersToken = "owner";
string g_sSecOwnersToken = "secowners";
string g_sBlackListToken = "blacklist";
string g_sPrefix;
//dialog handlers
key g_kAuthMenuID;
key g_kSensorMenuID;
integer g_iInterfaceChannel = -12587429;//added for attachment auth
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer COMMAND_BLACKLIST = 520;
// added so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;
integer NOTIFY = 550;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer FIND_AGENT = -9005;
//added for attachment auth (garvin)
integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
//new evolution style to handle attachment auth
integer INTERFACE_REQUEST  = -9006;
integer INTERFACE_RESPONSE = -9007;
//this can change
integer WEARERLOCKOUT=620;
//EXTERNAL MESSAGE MAP
integer EXT_COMMAND_COLLAR = 499;
string UPMENU = "BACK";
string CTYPE = "cuffs";
string g_sSetOwner = "✓ Owner";
string g_sSetSecOwner = "✓ Secowner";
string g_sSetBlackList = "✓ Blacklisted";
string g_sSetGroup = "Group ☐";
string g_sReset = "Reset All";
string g_sRemOwner = "✗ Owner";
string g_sRemSecOwner = "✗ Secowner";
string g_sRemBlackList = "✗ Blacklisted";
string g_sUnsetGroup = "Group ☒";
string g_sListOwners = "List Owners";
string g_sSetOpenAccess = "Public ☐";
string g_sUnsetOpenAccess = "Public ☒";
string g_sSetLimitRange = "LimitRange ☐";
string g_sUnsetLimitRange = "LimitRange ☒";
//request types
string g_sOwnerScan = "ownerscan";
string g_sSecOwnerScan = "secownerscan";
string g_sBlackListScan = "blacklistscan";
integer g_iOpenAccess; // 0: disabled, 1: openaccess
integer g_iLimitRange=1; // 0: disabled, 1: limited
integer g_iWearerlocksOut;
integer g_iRemenu = FALSE;
key g_kDialoger;//the person using the dialog.
integer g_iDialogerAuth; //auth of the person using the dialog
key REQUEST_KEY;
string g_sScript;
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
SayOwners() 
{ // Give a "you are owned by" message, nicely formatted.
    list ownernames = llList2ListStrided(llDeleteSubList(g_lOwners, 0, 0), 0, -1, 2);
    integer ownercount = llGetListLength(ownernames);
    if (ownercount) {
        string msg = "You are owned by ";
        if (ownercount == 1)  // if one person, then just name.
            msg += (string)ownernames;
        else if (ownercount == 2) // if two people, then A and B.
            msg += llDumpList2String(ownernames, " and ");
        else 
        {// if >2 people, then A, B, and C
            list init = llDeleteSubList(ownernames, -1, -1);
            list tail = llDeleteSubList(ownernames, 0, -2);
            msg += llDumpList2String(init, ", ");
            msg += ", and " + (string)tail;
        }
        msg += ".";// end with a period.
//        Notify(llGetOwner(), msg, FALSE);
        llMessageLinked(LINK_SET, NOTIFY, msg + "|FALSE",llGetOwner());
    }
}

sendToAttachmentInterface(string sMsg)
{
    llRegionSayTo(g_kWearer,g_iInterfaceChannel, "CollarCommand|" + (string) EXT_COMMAND_COLLAR + "|" + sMsg);
}

list AddUniquePerson(list lContainer, key kID, string sName, string sType)
{
    integer iIndex = llListFindList(lContainer, [(string)kID]);
    if (iIndex == -1)   //owner is not already in list.  add him/her
        lContainer += [(string)kID, sName];
    else   //owner is already in list.  just replace the name
        lContainer = llListReplaceList(lContainer, [sName], iIndex + 1, iIndex + 1);
    if (kID != g_kWearer)
    {
//        Notify(g_kWearer, "Added " + sName + " to " + sType + ".", FALSE);
        llMessageLinked(LINK_SET, NOTIFY, "Added " + sName + " to " + sType + ".|FALSE",g_kWearer);
        if (sType == "owner")
//            Notify(g_kWearer, "Your owner can have a lot  power over you and you consent to that by making them your owner on your " + CTYPE + ". They can put you in poses with chains, and lock your " + CTYPE + ".  Please read the help for more info. If you do not consent, you can use the command \"" + g_sPrefix + "runaway\" to remove all owners from the " + CTYPE + ".", FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Your owner can have a lot  power over you and you consent to that by making them your owner on your " + CTYPE + ". They can put you in poses with chains, and lock your " + CTYPE + ".  Please read the help for more info. If you do not consent, you can use the command \"" + g_sPrefix + "runaway\" to remove all owners from the " + CTYPE + ".|FALSE",g_kWearer);
    }
    if (sType == "owner" || sType == "secowner") 
//        Notify(kID, "You have been added to the " + sType + " list on " + llKey2Name(g_kWearer) + "'s " + CTYPE + ".\nFor help concerning the " + CTYPE + " usage either say \"" + g_sPrefix + "help\" in chat or go to " + g_sWikiURL + " .",FALSE);
        llMessageLinked(LINK_SET, NOTIFY, "You have been added to the " + sType + " list on " + llKey2Name(g_kWearer) + "'s " + CTYPE + ".\nFor help concerning the " + CTYPE + " usage either say \"" + g_sPrefix + "help\" in chat or go to " + g_sWikiURL + " .|FALSE",kID);
    return lContainer;
}

NewPerson(key kID, string sName, string sType)
{ //adds new owner, secowner, or blacklisted, as determined by type.
    if (sType == "owner")
    {
        g_lOwners = AddUniquePerson(g_lOwners, kID, sName, g_sRequestType);
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sOwnersToken + "=" + llDumpList2String(g_lOwners, ","), "");
    sendToAttachmentInterface("OwnerChange"); //added for attachment interface to announce owners have changed
    }
    else if (sType == "secowner")
    {
        g_lSecOwners = AddUniquePerson(g_lSecOwners, kID, sName, g_sRequestType);
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sSecOwnersToken + "=" + llDumpList2String(g_lSecOwners, ","), "");
    sendToAttachmentInterface("OwnerChange");//added for attachment interface to announce owners have changed
    }
    else if (sType == "blacklist")
    {
        g_lBlackList = AddUniquePerson(g_lBlackList, kID, sName, g_sRequestType);
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sBlackListToken + "=" + llDumpList2String(g_lBlackList, ","), "");
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
} 

FetchAvi(integer auth, string type, string name, key user)
{
    if (name == "") name = " ";
    string out = llDumpList2String(["getavi_", g_sScript, user, auth, type, name], "|");
    integer i = 0;
    list src = g_lOwners;
    if (type == "secowner") src += g_lSecOwners;
    else if (type == "blacklist") src = g_lBlackList;
    list exclude; // build list of existing-listed keys to exclude from name search
    for (; i < llGetListLength(src); i += 2)
        exclude += [llList2String(src, i)];
    if (llGetListLength(exclude))
        out += "|" + llDumpList2String(exclude, ",");
    llMessageLinked(LINK_THIS, FIND_AGENT, out, REQUEST_KEY = llGenerateKey());
}

AuthMenu(key kAv, integer iAuth)
{
    string sPrompt = "\n\n✓: add someone\n✗: remove someone\n☐: option is off\n☒: option is on";
    list lButtons = [g_sSetOwner, g_sSetSecOwner, g_sSetBlackList, g_sRemOwner, g_sRemSecOwner, g_sRemBlackList];
    if (g_kGroup=="") lButtons += [g_sSetGroup];    //set group
    else lButtons += [g_sUnsetGroup];    //unset group
    if (g_iOpenAccess) lButtons += [g_sUnsetOpenAccess];    //set open access
    else lButtons += [g_sSetOpenAccess];    //unset open access
    if (g_iLimitRange) lButtons += [g_sUnsetLimitRange];    //set ranged
    else lButtons += [g_sSetLimitRange];    //unset open ranged
    lButtons += [g_sReset];
    lButtons += [g_sListOwners];//list owners
    g_kAuthMenuID = Dialog(kAv, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

RemPersonMenu(key kID, list lPeople, string sType, integer iAuth)
{
    g_sRequestType = sType;
    string sPrompt = "\n\nChoose the person to remove.";
    list lButtons;
    //build a button list with the dances, and "More"
    //get number of secowners
    integer iNum= llGetListLength(lPeople);
    integer n;
    for (n=1; n <= iNum/2; n = n + 1)
    {
        string sName = llList2String(lPeople, 2*n-1);
        if (sName != "")
        {
            sPrompt += "\n" + (string)(n) + " - " + sName;
            lButtons += [(string)(n)];
        }
    }
    lButtons += ["Remove All"];
    g_kSensorMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

integer in_range(key kID) 
{
    if (g_iLimitRange) 
    {
        integer range = 20;
        vector kAvpos = llList2Vector(llGetObjectDetails(kID, [OBJECT_POS]), 0);
        if (llVecDist(llGetPos(), kAvpos) > range) {
            llDialog(kID, "\n\nNot in range...", [], 298479);
            return FALSE;
        }
        else return TRUE;
    }
    else return TRUE;
}

integer Auth(string kObjID, integer attachment)
{
    string kID = (string)llGetOwnerKey(kObjID); // if kObjID is an avatar key, then kID is the same key
    integer iNum;
    if (g_iWearerlocksOut && kID == (string)g_kWearer && !attachment)
        iNum = COMMAND_WEARERLOCKEDOUT;
    else if (~llListFindList(g_lOwners, [(string)kID]))
        iNum = COMMAND_OWNER;
    else if (llGetListLength(g_lOwners) == 0 && kID == (string)g_kWearer) //if no owners set, then wearer's cmds have owner auth
        iNum = COMMAND_OWNER;
    else if (~llListFindList(g_lBlackList, [(string)kID]))
        iNum = COMMAND_BLACKLIST;
    else if (~llListFindList(g_lSecOwners, [(string)kID]))
        iNum = COMMAND_SECOWNER;
    else if (kID == (string)g_kWearer)
        iNum = COMMAND_WEARER;
    else if ((g_iOpenAccess)&& ((key)kID != NULL_KEY))
    {
        if (in_range((key)kID))
            iNum = COMMAND_GROUP;
        else
            iNum = COMMAND_EVERYONE;
    }
    else if (g_iGroupEnabled && (string)llGetObjectDetails((key)kObjID, [OBJECT_GROUP]) == (string)g_kGroup && (key)kID != g_kWearer)
// meaning that the command came from an object set to our control group, and is not owned by the wearer
        iNum = COMMAND_GROUP;
    else if (llSameGroup(kID) && g_iGroupEnabled && kID != (string)g_kWearer)
    {
        if (in_range((key)kID))
            iNum = COMMAND_GROUP;
        else
            iNum = COMMAND_EVERYONE;
    }
    else
        iNum = COMMAND_EVERYONE;
    return iNum;
}

list RemovePerson(list lPeople, string sName, string sToken, key kCmdr)
{   //where "lPeople" is a 2-strided list in form key,name
    //looks for strides identified by "name", removes them if found, and returns the list
    //also handles notifications so as to reduce code duplication in the link message event
    //all our comparisons will be cast to lower case first
    sName = llToLower(sName);
    integer iChange = FALSE;
    integer n;
    key kRemovedPerson;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(lPeople) - 1; n >= 0; n = n - 2)
    {
        string sThisName = llToLower(llList2String(lPeople, n));
        if (sName == sThisName)
        {   //remove name and key
            kRemovedPerson=llList2String(lPeople,n - 1);
            lPeople = llDeleteSubList(lPeople, n - 1, n);
            iChange = TRUE;
        }
    }
    if (iChange)
    {
        if (sToken == g_sOwnersToken || sToken == g_sSecOwnersToken)
        {// is it about owners?
            if (kRemovedPerson!=g_kWearer)
            {// if it isnt the wearer, we are nice and notify them
                if (sToken == g_sOwnersToken)
//                    Notify(kRemovedPerson,"You have been removed as owner on the " + CTYPE + " of " + llKey2Name(g_kWearer) + ".",FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You have been removed as owner on the " + CTYPE + " of " + llKey2Name(g_kWearer) + ".|FALSE",kRemovedPerson);
                else
//                    Notify(kRemovedPerson,"You have been removed as secowner on the " + CTYPE + " of " + llKey2Name(g_kWearer) + ".",FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You have been removed as secowner on the " + CTYPE + " of " + llKey2Name(g_kWearer) + ".|FALSE",kRemovedPerson);
            }
        sendToAttachmentInterface("OwnerChange");//whisper to attachments about owner and secowner changes
        }
        if (llGetListLength(lPeople)>0)//save to db
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + sToken + "=" + llDumpList2String(lPeople, ","), "");
        else
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + sToken, "");
//        Notify(kCmdr, sName + " removed from list.", TRUE);
        llMessageLinked(LINK_SET, NOTIFY, sName + " removed from list.|TRUE",kCmdr);
    }
    else
//        Notify(kCmdr, "Error: '" + sName + "' not in list.",FALSE);
        llMessageLinked(LINK_SET, NOTIFY,  "Error: '" + sName + "' not in list.|FALSE",kCmdr);
    return lPeople;
}

integer isKey(string sIn) 
{
    if ((key)sIn) return TRUE;
    return FALSE;
}

integer OwnerCheck(key kID)
{//checks whether id has owner auth.  returns TRUE if so, else notifies person that they don't have that power
    //used in menu processing for when a non owner clicks an owner-only button
    if (Auth((string)kID, FALSE) == COMMAND_OWNER)
        return TRUE;
    else
    {
//        Notify(kID, "Sorry, only an owner can do that.", FALSE);
        llMessageLinked(LINK_SET, NOTIFY, "Sorry, only an owner can do that.|FALSE",kID);
        return FALSE;
    }
}

NotifyInList(list lStrideList, string sOwnerType)
{
    integer i;
    integer l=llGetListLength(lStrideList);
    key k;
    string sSubName = llKey2Name(g_kWearer);
    for (i = 0; i < l; i = i +2)
    {
        k = (key)llList2String(lStrideList,i);
        if (k != g_kWearer)
//            Notify(k,"You have been removed as " + sOwnerType + " on the " + CTYPE + " of " + sSubName + ".",FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "You have been removed as " + sOwnerType + " on the " + CTYPE + " of " + sSubName + ".|FALSE",k);
    }
}

// returns TRUE if eligible (AUTHED link message number)
integer UserCommand(integer iNum, string sStr, key kID) // here iNum: auth value, sStr: user command, kID: avatar id
{
    if (iNum == COMMAND_EVERYONE) return TRUE;  // No command for people with no privilege in this plugin.
    else if (iNum > COMMAND_EVERYONE || iNum < COMMAND_OWNER) return FALSE; // sanity check
    if (sStr == "menu "+g_sSubMenu)  //NG
        AuthMenu(kID, iNum);
    else if (sStr == "refreshmenu")
            {
                llSleep (0.1);
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
            }
    else if (sStr == "settings" || sStr == "listowners")
    {   //say owner, secowners, group
        if (iNum == COMMAND_OWNER || kID == g_kWearer)
        {  //Do Owners list
            integer n;
            integer iLength = llGetListLength(g_lOwners);
            string sOwners;
            for (n = 0; n < iLength; n = n + 2)
                sOwners += "\n" + llList2String(g_lOwners, n + 1) + " (" + llList2String(g_lOwners, n) + ")";
//            Notify(kID, "Owners: " + sOwners,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Owners: " + sOwners +".|FALSE",kID);
            iLength = llGetListLength(g_lSecOwners);//Do Secowners list
            string sSecOwners;
            for (n = 0; n < iLength; n = n + 2)
                sSecOwners += "\n" + llList2String(g_lSecOwners, n + 1) + " (" + llList2String(g_lSecOwners, n) + ")";
//            Notify(kID, "Secowners: " + sSecOwners,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Secowners: " + sSecOwners +".|FALSE",kID);
            iLength = llGetListLength(g_lBlackList);
            string sBlackList;
            for (n = 0; n < iLength; n = n + 2)
                sBlackList += "\n" + llList2String(g_lBlackList, n + 1) + " (" + llList2String(g_lBlackList, n) + ")";
//            Notify(kID, "Black List: " + sBlackList,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Black List: " + sBlackList +".|FALSE",kID);
//            Notify(kID, "Group: " + g_sGroupName,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Group: " + g_sGroupName +".|FALSE",kID);
//            Notify(kID, "Group Key: " + (string)g_kGroup,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Group Key: " + (string)g_kGroup +".|FALSE",kID);
            string sVal; if (g_iOpenAccess) sVal="true"; else sVal="false";
//            Notify(kID, "Open Access: "+ sVal,FALSE);
            llMessageLinked(LINK_SET, NOTIFY,  "Open Access: "+ sVal +".|FALSE",kID);
            string sValr; if (g_iLimitRange) sValr="true"; else sValr="false";
//            Notify(kID, "LimitRange: "+ sValr,FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "LimitRange: "+ sValr +".|FALSE",kID);
        }
        else //Notify(kID, "Only Owners & Wearer may access this command",FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Only Owners & Wearer may access this command.|FALSE",kID);
    }
    else if (sStr == "owners")   //give owner menu
        AuthMenu(kID, iNum);
    else if (iNum == COMMAND_OWNER)
    {//respond to messages to set or unset owner, group, or secowners.  only owner may do these things
        list lParams = llParseString2List(sStr, [" "], []);
        string sCommand = llList2String(lParams, 0);
        if ((key)llList2String(lParams, 1))
        {
            key new = (key)llList2String(lParams, 1);
            g_sRequestType = sCommand;
            if (g_sRequestType != "blacklist" && !~llSubStringIndex(g_sRequestType, "owner")) return TRUE;
            else if (g_sRequestType != "blacklist" && new != g_kWearer)
            {
//                Notify(kID, "Requesting confirmation from " + llKey2Name(new), FALSE);
                 llMessageLinked(LINK_SET, NOTIFY, "Requesting confirmation from " + llKey2Name(new) + "|FALSE",kID);
                g_kDialoger = kID;
                string prompt = llKey2Name(kID) + " would like to add you as\na";
                if (g_sRequestType == "owner") prompt += "n";
                else if (g_sRequestType == "secowner") prompt += " secondary";
                prompt += " owner on ";
                if (kID == g_kWearer) prompt += "their ";
                else prompt += llKey2Name(g_kWearer) + "'s ";
                prompt += "" + CTYPE + ".\nDo you accept?";
                g_kAuthMenuID = Dialog(new, prompt, ["Yes", "No"], [], 0, iNum);
                return TRUE;
            }
            NewPerson(new, llKey2Name(new), g_sRequestType);
            return TRUE;
        }
        if (sCommand == "owner")
        { //set a new owner.
            //if no owner at all specified:
            if (llList2String(lParams, 1) == "")
            {
                AuthMenu(kID, iNum);
                return TRUE;
            }
            g_sRequestType = "owner";
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //record owner name
            g_sTmpName = llDumpList2String(lParams, " ");
            if(llToLower(g_sTmpName) == llToLower(llKey2Name(g_kWearer)))
                NewPerson(g_kWearer, g_sTmpName, "owner");
            else
                FetchAvi(iNum, g_sRequestType, g_sTmpName, kID);
        }
        else if (sCommand == "remowners")
        { //remove secowner, if in the list
            g_sRequestType = "";//Nan: this used to be set to "remowners" but that NEVER gets filtered on elsewhere in the script.
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //name of person concerned
            g_sTmpName = llDumpList2String(lParams, " ");
            if (g_sTmpName=="")
                RemPersonMenu(kID, g_lOwners, "remowners", iNum);
            else if(llToLower(g_sTmpName) == "remove all")
            {
//                Notify(kID, "Removing of all owners started!",TRUE);
                llMessageLinked(LINK_SET, NOTIFY, "Removing of all owners started!|TRUE",kID);
                NotifyInList(g_lOwners, g_sOwnersToken);
                g_lOwners = [];
                llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + g_sOwnersToken, "");
//                Notify(kID, "Everybody was removed from the owner list!",TRUE);
                llMessageLinked(LINK_SET, NOTIFY, "Everybody was removed from the owner list!|TRUE",kID);
            }
            else
                g_lOwners = RemovePerson(g_lOwners, g_sTmpName, g_sOwnersToken, kID);
        }
        else if (sCommand == "secowner")
        { //set a new secowner
            g_sRequestType = "secowner";
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //record owner name
            g_sTmpName = llDumpList2String(lParams, " ");
            if (llGetListLength(g_lSecOwners) == 20)
//                Notify(kID, "The maximum of 10 secowners is reached, please clean up or use SetGroup.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "The maximum of 10 secowners is reached, please clean up or use SetGroup.|FALSE",kID);
            else
            {
                if(llToLower(g_sTmpName) == llToLower(llKey2Name(g_kWearer)))
                    NewPerson(g_kWearer, g_sTmpName, "secowner");
                else
                    FetchAvi(iNum, g_sRequestType, g_sTmpName, kID);
            }
        }
        else if (sCommand == "remsecowner")
        { //remove secowner, if in the list
            g_sRequestType = "";
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //name of person concerned
            g_sTmpName = llDumpList2String(lParams, " ");
            if (g_sTmpName=="")
                RemPersonMenu(kID, g_lSecOwners, "remsecowner", iNum);
            else if(llToLower(g_sTmpName) == "remove all")
            {
//                Notify(kID, "Removing of all secowners started!",TRUE);
                llMessageLinked(LINK_SET, NOTIFY, "Removing of all secowners started!|TRUE",kID);
                NotifyInList(g_lSecOwners, g_sSecOwnersToken);
                g_lSecOwners = [];
                llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "secowners", "");
//                Notify(kID, "Everybody was removed from the secondary owner list!",TRUE);
                llMessageLinked(LINK_SET, NOTIFY, "Everybody was removed from the secondary owner list!|TRUE",kID);
            }
            else
                g_lSecOwners = RemovePerson(g_lSecOwners, g_sTmpName, g_sSecOwnersToken, kID);
        }
        else if (sCommand == "blacklist")
        { //blackList an avatar
            g_sRequestType = "blacklist";
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //record blacklisted name
            g_sTmpName = llDumpList2String(lParams, " ");
            if (llGetListLength(g_lBlackList) == 20)
//                Notify(kID, "The maximum of 10 blacklisted is reached, please clean up.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "The maximum of 10 blacklisted is reached, please clean up.|FALSE",kID);
            else
                FetchAvi(iNum, g_sRequestType, g_sTmpName, kID);
        }
        else if (sCommand == "remblacklist")
        { //remove blacklisted, if in the list
            g_sRequestType = "";
            //pop the command off the param list, leaving only first and last name
            lParams = llDeleteSubList(lParams, 0, 0);
            //name of person concerned
            g_sTmpName = llDumpList2String(lParams, " ");
            if (g_sTmpName=="")
                RemPersonMenu(kID, g_lBlackList, "remblacklist", iNum);
            else if(llToLower(g_sTmpName) == "remove all")
            {
                g_lBlackList = [];
                llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + g_sBlackListToken, "");
//                Notify(kID, "Everybody was removed from the blacklist!", TRUE);
                llMessageLinked(LINK_SET, NOTIFY, "Everybody was removed from the blacklist!|TRUE",kID);
            }
            else
                g_lBlackList = RemovePerson(g_lBlackList, g_sTmpName, g_sBlackListToken, kID);
        }
        else if (sCommand == "setgroup")
        {
            g_sRequestType = "group";
            if (isKey(llList2String(lParams, 1)))//if no arguments given, use current group, else use key provided
                g_kGroup = (key)llList2String(lParams, 1);
            else //record current group key
                g_kGroup = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);
            if (g_kGroup != "")
            {
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "group=" + (string)g_kGroup, "");
                g_iGroupEnabled = TRUE;
                g_kDialoger = kID;
                g_iDialogerAuth = iNum;
                //get group name from
                g_kGroupHTTPID = llHTTPRequest("http://world.secondlife.com/group/" + (string)g_kGroup, [], "");
            }
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
        }
        else if (sCommand == "setgroupname")
        {
            g_sGroupName = llDumpList2String(llList2List(lParams, 1, -1), " ");
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "groupname=" + g_sGroupName, "");
        }
        else if (sCommand == "unsetgroup")
        {
            g_kGroup = "";
            g_sGroupName = "";
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "group", "");
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "groupname", "");
            g_iGroupEnabled = FALSE;
//            Notify(kID, "Group unset.", FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Group unset.|FALSE",kID);
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
            //added for attachment interface to announce owners have changed
        sendToAttachmentInterface("OwnerChange");
        }
        else if (sCommand == "setopenaccess")
        {
            g_iOpenAccess = TRUE;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "openaccess=" + (string) g_iOpenAccess, "");
//            Notify(kID, "Your " + CTYPE + " are open to the public.", FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Your " + CTYPE + " are open to the public.|FALSE",kID);
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
            sendToAttachmentInterface("OwnerChange");
        }
        else if (sCommand == "unsetopenaccess")
        {
            g_iOpenAccess = FALSE;
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "openaccess", "");
//            Notify(kID, "Your " + CTYPE + " are closed to the public.", FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Your " + CTYPE + " are closed to the public.|FALSE",kID);
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
            //added for attachment interface to announce owners have changed
            sendToAttachmentInterface("OwnerChange");
        }
        else if (sCommand == "setlimitrange")
        {
            g_iLimitRange = TRUE;
            // as the default is range limit on, we do not need to store anything for this
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "limitrange", "");
//            Notify(kID, "Range is limited.", FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Range is limited.|FALSE",kID);
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
        }
        else if (sCommand == "unsetlimitrange")
        {
            g_iLimitRange = FALSE;
            // save off state for limited range (default is on)
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "limitrange=" + (string) g_iLimitRange, "");
//            Notify(kID, "Range is simwide.", FALSE);
            llMessageLinked(LINK_SET, NOTIFY, "Range is simwide.|FALSE",kID);
            if(g_iRemenu)
            {
                g_iRemenu = FALSE;
                AuthMenu(kID, iNum);
            }
        }
    }
    return TRUE;
}
SetPrefix(string sValue)
{
    if (sValue != "auto") g_sPrefix = sValue;
    else
    {
        list name = llParseString2List(llKey2Name(g_kWearer), [" "], []);
        string init = llGetSubString(llList2String(name, 0), 0, 0);
        init += llGetSubString(llList2String(name, 1), 0, 0);
        g_sPrefix = llToLower(init);
    }
}

default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer = llGetOwner();
        SetPrefix("auto");
        //added for attachment auth
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        // Request owner list.  Be careful about doing this in all scripts,
        // because we can easily flood the 64 event limit in LSL's event queue
        // if all the scripts send a ton of link messages at the same time on
        // startup.
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sScript + g_sOwnersToken, "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sScript + g_sSecOwnersToken, "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sScript + g_sBlackListToken, "");
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {  //authenticate messages on COMMAND_NOAUTH
        if (iNum == COMMAND_NOAUTH)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "auth_owner")
                {
                    llOwnerSay ("Owner list has been updated.");
                    g_lOwners = llParseString2List(sValue, [","], []);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sOwnersToken + "=" + llDumpList2String(g_lOwners, ","), "");
                    SayOwners();
                }
            if (sToken == "auth_secowners")
                {
                    llOwnerSay ("SecOwner list has been updated.");
                    g_lSecOwners = llParseString2List(sValue, [","], []);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sSecOwnersToken + "=" + llDumpList2String(g_lSecOwners, ","), "");
                    SayOwners();
                }            
            if (sToken == "auth_blacklist")
                {
                    llOwnerSay ("Black list has been updated.");
                    g_lBlackList = llParseString2List(sValue, [","], []);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + g_sBlackListToken + "=" + llDumpList2String(g_lBlackList, ","), "");
                    SayOwners();
                }
            integer iAuth = Auth((string)kID, FALSE);
            if ((iNum == COMMAND_OWNER || kID == g_kWearer) && (sStr=="reset"))
                llMessageLinked(LINK_SET, NOTIFY, "The command 'reset' is deprecated. Please use 'runaway' to leave the owner and clear all lock settings in the " + CTYPE + ".|FALSE",kID);
//                Notify(kID, "The command 'reset' is deprecated. Please use 'runaway' to leave the owner and clear all lock settings in the " + CTYPE + ".", FALSE);
            else if ((iAuth == COMMAND_OWNER || kID == g_kWearer) && sStr == "runaway")
            {   // note that this will work *even* if the wearer is blacklisted or locked out
                // otherwise forbid anybody who is not the wearer or primary owner
//                Notify(g_kWearer, "Running away from all owners started, your owners will now be notified!",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Running away from all owners started, your owners will now be notified!|FALSE",kID);
                integer n;
                integer stop = llGetListLength(g_lOwners);
                for (n = 0; n < stop; n += 2)
                {
                    key kOwner = (key)llList2String(g_lOwners, n);
                    if (kOwner != g_kWearer)
//                        Notify(kOwner, llKey2Name(g_kWearer) + " has run away!",FALSE);
                        llMessageLinked(LINK_SET, NOTIFY, llKey2Name(g_kWearer) + " has run away!|FALSE",kOwner);
                }
                llMessageLinked(LINK_THIS, LM_SETTING_DELETE, g_sScript + "all", "");
//                Notify(g_kWearer, "Runaway finished, the " + CTYPE + " will now release locks!",FALSE);
                llMessageLinked(LINK_SET, NOTIFY,  "Runaway finished, the " + CTYPE + " will now release locks!|FALSE",g_kWearer);
                // moved reset request from settings to here to allow noticifation of owners.
                llMessageLinked(LINK_SET, COMMAND_OWNER, "clear", kID); // clear RLV restrictions
                llMessageLinked(LINK_SET, COMMAND_OWNER, "runaway", kID); // this is not a LM loop, since it is now really authed
                llResetScript();
            }
            else
                llMessageLinked(LINK_SET, iAuth, sStr, kID);
            return; // NOAUTH messages need go no further
        }
        else if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sScript)
            {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == g_sOwnersToken)
                {
                    // temporarily stash owner list so we can see if it's changing.
                    list tmpowners = g_lOwners;
                    g_lOwners = llParseString2List(sValue, [","], []);
                    // only say the owner list if it has changed.  This includes on
                    // rez, since we reset (and therefore blank the owner list) on rez.
                    if (llGetListLength(g_lOwners) && tmpowners != g_lOwners) SayOwners();
                }
                else if (sToken == "group")
                {
                    g_kGroup = (key)sValue;
                    if (g_kGroup != "")//check to see if the object's group is set properly
                    {
                        if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == g_kGroup)
                            g_iGroupEnabled = TRUE;
                        else
                            g_iGroupEnabled = FALSE;
                    }
                    else
                        g_iGroupEnabled = FALSE;
                }
                else if (sToken == "groupname")
                    g_sGroupName = sValue;
                else if (sToken == "openaccess")
                    g_iOpenAccess = (integer)sValue;
                else if (sToken == "limitrange")
                    g_iLimitRange = (integer)sValue;
                else if (sToken == "secowners")
                    g_lSecOwners = llParseString2List(sValue, [","], [""]);
                else if (sToken == "blacklist")
                    g_lBlackList = llParseString2List(sValue, [","], [""]);
            }
            else if (sToken == "Global_prefix") SetPrefix(sValue);
            else if (sToken == "Global_CType") CTYPE = sValue;
        }
        else if (iNum == LM_SETTING_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "Global_prefix") SetPrefix(sValue);
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
             llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == COMMAND_SAFEWORD)
        {
            string sSubName = llKey2Name(g_kWearer);
            string sSubFirstName = llList2String(llParseString2List(sSubName, [" "], []), 0);
            integer n;
            integer iStop = llGetListLength(g_lOwners);
            for (n = 0; n < iStop; n += 2)
            {
                key kOwner = (key)llList2String(g_lOwners, n);
//                Notify(kOwner, "Your sub " + sSubName + " has used the safeword. Please check on " + sSubFirstName +"'s well-being and if further care is required.",FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Your sub " + sSubName + " has used the safeword. Please check on " + sSubFirstName +"'s well-being and if further care is required.|FALSE",kOwner);
            }
            llMessageLinked(LINK_THIS, INTERFACE_RESPONSE, "safeword", "");
        }        
        else if (iNum == ATTACHMENT_REQUEST)
        {
          integer iAuth = Auth((string)kID, TRUE);
          llMessageLinked(LINK_SET, ATTACHMENT_RESPONSE, (string)iAuth, kID);
        }
        else if (iNum == INTERFACE_REQUEST)
        {
            list lParams = llParseString2List(sStr, ["|"], []);
            string sTarget = llList2String(lParams, 0);
            string sCommand = llList2String(lParams, 1);
            if (sTarget == "auth_")
            {
                if (sCommand == "level")
                {
                    string sAuth = (string)Auth((string)kID, TRUE);
                    lParams = llListReplaceList(lParams, ["level=" + sAuth], 1, 1);
                }
                else return; // do not send response if the message was erroneous
                llMessageLinked(LINK_SET, INTERFACE_RESPONSE, llDumpList2String(lParams, "|"), kID);
            }
        }
        else if (iNum == WEARERLOCKOUT)
        {
            if (sStr == "on")
                g_iWearerlocksOut=TRUE;
            else if (sStr == "off")
                g_iWearerlocksOut=FALSE;
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (llListFindList([g_kAuthMenuID, g_kSensorMenuID], [kID]) != -1)
            {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (kID == g_kAuthMenuID)
                {
                    if (sMessage == UPMENU)
                    {
                        llMessageLinked(LINK_SET, iAuth,  "menu "+ g_sParentMenu, kAv);
                        return;
                    }
                    else if (sMessage == "Yes")
                    {
                        NewPerson(kAv, llKey2Name(kAv), g_sRequestType);
                        return;
                    }
                    else if (sMessage == "No")
                    {
//                        Notify(g_kDialoger, llKey2Name(kAv) + " has declined your request.", FALSE);
                        llMessageLinked(LINK_SET, NOTIFY, llKey2Name(kAv) + " has declined your request.|FALSE",g_kDialoger);
                        return;
                    }
                    else if (sMessage == g_sSetOwner)
                    {
                        if (OwnerCheck(kAv))
                        {
                            FetchAvi(iAuth, "owner", "", kAv);
                            return;
                        }
                    }
                    else if (sMessage == g_sSetSecOwner)
                    {
                        if (OwnerCheck(kAv))
                        {
                            FetchAvi(iAuth, "secowner", "", kAv);
                            return;
                        }
                    }
                    else if (sMessage == g_sSetBlackList)
                    {
                        if (OwnerCheck(kAv))
                        {
                            FetchAvi(iAuth, "blacklist", "", kAv);
                            return;
                        }
                    }
                    else if (sMessage == g_sRemOwner)
                    {
                        if (OwnerCheck(kAv))
                        {
                            RemPersonMenu(kAv, g_lOwners, "remowners", iAuth);
                            return;
                        }
                    }
                    else if (sMessage == g_sRemSecOwner)
                    {   //popup list of secowner if owner clicked
                        if (OwnerCheck(kAv))
                        {
                            RemPersonMenu(kAv, g_lSecOwners, "remsecowner", iAuth);
                            return;
                        }
                    }
                    else if (sMessage == g_sRemBlackList)
                    {   //popup list of secowner if owner clicked
                        if (OwnerCheck(kAv))
                        {
                            RemPersonMenu(kAv, g_lBlackList, "remblacklist", iAuth);
                            return;
                        }
                    }
                    else if (sMessage == g_sSetGroup)
                        UserCommand(iAuth, "setgroup", kAv);
                    else if (sMessage == g_sUnsetGroup)
                        UserCommand(iAuth, "unsetgroup", kAv);
                    else if (sMessage == g_sSetOpenAccess)
                        UserCommand(iAuth, "setopenaccess", kAv);
                    else if (sMessage == g_sUnsetOpenAccess)
                        UserCommand(iAuth, "unsetopenaccess", kAv);
                    else if (sMessage == g_sSetLimitRange)
                        UserCommand(iAuth, "setlimitrange", kAv);
                    else if (sMessage == g_sUnsetLimitRange)
                        UserCommand(iAuth, "unsetlimitrange", kAv);
                    else if (sMessage == g_sListOwners)
                        UserCommand(iAuth, "listowners", kAv);
                    else if (sMessage == g_sReset) // separate routine
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "runaway", kAv);
                    AuthMenu(kAv, iAuth);
                }
                else if (kID == g_kSensorMenuID)
                {
                    if (sMessage != UPMENU)
                    {
                        if (sMessage == "Remove All")
                        {
                            if (OwnerCheck(kAv))//g_sRequestType should be g_sRemOwner, g_sRemSecOwner, or g_sRemBlackList
                                UserCommand(iAuth, g_sRequestType + " Remove All", kAv);
                        }
                        else if (llGetSubString(g_sRequestType,0,2) == "rem")
                        {
                            if (OwnerCheck(kAv))
                            { //build a chat command to send to remove the person
                                string sCmd = g_sRequestType;
                                //convert the menu button number to a name
                                if (g_sRequestType == "remowners")
                                    sCmd += " " + llList2String(g_lOwners, (integer)sMessage*2 - 1);
                                else if(g_sRequestType == "remsecowner")
                                    sCmd += " " + llList2String(g_lSecOwners, (integer)sMessage*2 - 1);
                                else if(g_sRequestType == "remblacklist")
                                    sCmd += " " + llList2String(g_lBlackList, (integer)sMessage*2 - 1);
                                UserCommand(iAuth, sCmd, kAv);
                            }
                        }
                        else if(g_sRequestType == g_sOwnerScan)
                            UserCommand(iAuth, "owner " + sMessage, kAv);
                        else if(g_sRequestType == g_sSecOwnerScan)
                            UserCommand(iAuth, "secowner " + sMessage, kAv);
                        else if(g_sRequestType == g_sBlackListScan)
                            UserCommand(iAuth, "blacklist " + sMessage, kAv);
                    }
                    AuthMenu(kAv, iAuth);
                }
            }
        }
        else if(iNum == FIND_AGENT)
        {
            if (kID != REQUEST_KEY) return;
            list params = llParseString2List(sStr, ["|"], []);
            if (llList2String(params, 0) != g_sScript) return;
            g_sRequestType = llList2String(params, 4);
            key new = (key)llList2String(params, 5);
            if (g_sRequestType != "blacklist" && new != g_kWearer)
            {
                key user = (key)llList2String(params, 2);
//                Notify(user, "Requesting confirmation from " + llKey2Name(new), FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Requesting confirmation from " + llKey2Name(new) +" |FALSE",user);
                g_kDialoger = user;
                string prompt = llKey2Name(user) + " would like to add you as\na";
                if (g_sRequestType == "owner") prompt += "n";
                else if (g_sRequestType == "secowner") prompt += " secondary";
                prompt += " owner on ";
                if (user == g_kWearer) prompt += "their ";
                else prompt += llKey2Name(g_kWearer) + "'s ";
                prompt += "" + CTYPE + ".\nDo you accept?";
                g_kAuthMenuID = Dialog(new, prompt, ["Yes", "No"], [], 0, iNum);
                return;
            }
            NewPerson(new, llKey2Name(new), g_sRequestType);
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
            llResetScript();
    }

    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kGroupHTTPID)
        {
            g_sGroupName = "X";
            if (iStatus == 200)
            {
                integer iPos = llSubStringIndex(sBody, "<title>");
                integer iPos2 = llSubStringIndex(sBody, "</title>");
                if ((~iPos) // Found
                    && iPos2 > iPos // Has to be after it
                    && iPos2 <= iPos + 43 // 36 characters max (that's 7+36 because <title> has 7)
                    && !~llSubStringIndex(sBody, "AccessDenied") // Check as per groupname.py (?)
                   )
                    g_sGroupName = llGetSubString(sBody, iPos + 7, iPos2 - 1);
            }
            if (g_sGroupName == "X")
//                Notify(g_kDialoger, "Group set to (group name hidden).", FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Group set to (group name hidden).|FALSE",g_kDialoger);
            else
//                Notify(g_kDialoger, "Group set to " + g_sGroupName + ".", FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Group set to " + g_sGroupName + ".|FALSE",g_kDialoger);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + "groupname=" + g_sGroupName, "");
        }
    }
}