////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - menu cuff                                  //
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

//on start, send request for submenu names
//on getting submenu name, add to list if not already present
//on menu request, give dialog, with alphabetized list of submenus
//on listen, send submenu link message

//-------cuff change---------------
list g_lMenuNames = ["Main", "Help/Debug"];
//---end cuff change---------------

list g_lMenus;//exists in parallel to g_lMenuNames, each entry containing a pipe-delimited string with the items for the corresponding menu
list g_lMenuPrompts = [
//WS: let's query for version properly; the static number is supposed to be a reminder not a solution
"\n\nWelcome to the Main Menu\nOpenNC Version 3.960",
"\n\nPlease think about joining the support group, search for OpenNC in group search",
"\n\nThis menu grants access to every installed AddOn.\n"
];

list g_lMenuIDs;//3-strided list of avatars given menus, their dialog ids, and the name of the menu they were given
integer g_iMenuStride = 3;
integer g_iScriptCount;//when the scriptcount changes, rebuild menus

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_EVERYONE = 504;
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
string UPMENU = "BACK";
string HELPCARD = "OpenNC cuffs Guide";
string helpcard = "HelpCard";
string REFRESH_MENU = "Fix Menus";
string USER_GROUP = "OpenNC Grp";
string USER_GROUP_ID = "a6e8c5c4-b1e3-0ceb-175d-a0eb6685a807";
string WIKI = "ℹ";

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
} 

Menu(string sName, key kID, integer iAuth)
{
    integer iMenuIndex = llListFindList(g_lMenuNames, [sName]);  
    if (iMenuIndex != -1)
    {
        list lItems = llParseString2List(llList2String(g_lMenus, iMenuIndex), ["|"], []);
        string sPrompt = llList2String(g_lMenuPrompts, iMenuIndex);
        list lUtility = [];
        if (sName != "Main")
        {
            lUtility = [UPMENU];
        }
        key kMenuID = Dialog(kID, sPrompt, lItems, lUtility, 0, iAuth);
        integer iIndex = llListFindList(g_lMenuIDs, [kID]);
        if (~iIndex)
        { //we've alread given a menu to this user.  overwrite their entry
            g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
        }
        else
        { //we've not already given this user a menu. append to list
            g_lMenuIDs += [kID, kMenuID, sName];
        }
    }
}

integer KeyIsAv(key kID)
{
    return llGetAgentSize(kID) != ZERO_VECTOR;
}

MenuInit()
{
    g_lMenus = ["","",""];
    integer n;
    integer iStop = llGetListLength(g_lMenuNames);
    for (n = 0; n < iStop; n++)
    {
        string sName = llList2String(g_lMenuNames, n);
        if (sName != "Main")
        { //make each submenu appear in Main
            HandleMenuResponse("Main|" + sName);
            //request children of each submenu
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, sName, "");            
        }
    }
    //give the help menu GIVECARD and REFRESH_MENU buttons    
    HandleMenuResponse("Help/Debug|" + REFRESH_MENU);      
    HandleMenuResponse("Help/Debug|" + USER_GROUP);
    HandleMenuResponse("Help/Debug|" + helpcard);
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Main", ""); 
}

HandleMenuResponse(string entry)
{
    list lParams = llParseString2List(entry, ["|"], []);
    string sName = llList2String(lParams, 0);
    integer iMenuIndex = llListFindList(g_lMenuNames, [sName]);
    if (iMenuIndex != -1)
    {             
        string g_sSubMenu = llList2String(lParams, 1);
        //only add submenu if not already present
        list lGuts = llParseString2List(llList2String(g_lMenus, iMenuIndex), ["|"], []);
        if (llListFindList(lGuts, [g_sSubMenu]) == -1)
        {
            lGuts += [g_sSubMenu];
            lGuts = llListSort(lGuts, 1, TRUE);
            g_lMenus = llListReplaceList(g_lMenus, [llDumpList2String(lGuts, "|")], iMenuIndex, iMenuIndex);
        }
    }
}

HandleMenuRemove(string sStr)
{
    list lParams = llParseString2List(sStr, ["|"], []);
    string parent = llList2String(lParams, 0);
    string child = llList2String(lParams, 1);
    integer iMenuIndex = llListFindList(g_lMenuNames, [parent]);
    if (iMenuIndex != -1)
    {
        list lGuts = llParseString2List(llList2String(g_lMenus, iMenuIndex), ["|"], []);
        integer gutiIndex = llListFindList(lGuts, [child]);
        //only remove if it's there
        if (gutiIndex != -1)        
        {
            lGuts = llDeleteSubList(lGuts, gutiIndex, gutiIndex);
            g_lMenus = llListReplaceList(g_lMenus, [llDumpList2String(lGuts, "|")], iMenuIndex, iMenuIndex);                    
        }        
    } 
}

integer UserCommand(integer iNum, string sStr, key kID)
{
    if (iNum == COMMAND_NOAUTH) 
    {
        llMessageLinked(LINK_SET, iNum, sStr, kID); return TRUE;
    }
    if (iNum == COMMAND_EVERYONE) return TRUE;  // No command for people with no privilege in this plugin.
    else if (iNum > COMMAND_EVERYONE || iNum < COMMAND_OWNER) return FALSE; // sanity check
    list lParams = llParseString2List(sStr, [" "], []);
    string sCmd = llList2String(lParams, 0);
    if (sStr == "cmenu") Menu("Main", kID, iNum);
    else if (sCmd == "menu")
    {
        string sSubmenu = llGetSubString(sStr, 5, -1);
        if (llListFindList(g_lMenuNames, [sSubmenu]) != -1);
        Menu(sSubmenu, kID, iNum);
    }
    else if (sStr == "chelp") llGiveInventory(kID, HELPCARD);                
    else if (sStr == "cdebug") Menu("Help/Debug", kID, iNum);
    else if (sCmd == "refreshmenu1")
    {
        llDialog(kID, "\n\nRebuilding menu.\n\nThis may take several seconds.", [], -341321);
        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "refreshmenu", kID);
        llResetScript();
    }
    return TRUE;
}

default
{
    state_entry()
    {
        llSleep(1.0);//delay sending this message until we're fairly sure that other scripts have reset too, just in case
        g_iScriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
        MenuInit();
    }
    //-------extra cuff---------------
    touch_start(integer num)//so we can touch the cuff
    {
        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "cmenu", llDetectedKey(0));
    }
    //-------end extra cuff---------------
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == COMMAND_NOAUTH) return;
        if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == MENUNAME_RESPONSE)
        { //sStr will be in form of "parent|menuname"
            //ignore unless parent is in our list of menu names
            HandleMenuResponse(sStr);
        }
        else if (iNum == MENUNAME_REMOVE)
        {
            HandleMenuRemove(sStr);
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            { //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

                    if (sMessage == USER_GROUP)
                    {
                        llInstantMessage(kAv,"\n\nJoin secondlife:///app/group/" + USER_GROUP_ID + "/about " + "for friendly support.\n");
                        Menu("Help/Debug", kAv, iAuth);
                    }
                    else if (sMessage == REFRESH_MENU)
                    {//send a command telling other plugins to rebuild their menus
                        UserCommand(iAuth, "refreshmenu1", kAv);
                    }
                    else if (sMessage == helpcard)
                    {//give out the help card
                        llGiveInventory(kAv, HELPCARD);
                    }
                    else if (sMessage == UPMENU)
                    {
                        Menu("Main", kAv, iAuth);
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, iAuth, "menu "+sMessage, kAv);
                    }
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            //remove stride from g_lMenuIDs
            //we have to subtract from the index because the dialog id comes in the middle of the stride
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
    
    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY)
        {
            if (llGetInventoryNumber(INVENTORY_SCRIPT) != g_iScriptCount)
            {//a script has been added or removed.  Reset to rebuild menu
                llResetScript();
            }
        }
    }
}