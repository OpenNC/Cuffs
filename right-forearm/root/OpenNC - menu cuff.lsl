////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - menu cuff                                  //
//                            version 3.961                                       //
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
list g_lMenuNames = ["Main", "Help/About"];
//---end cuff change---------------

list g_lMenus;//exists in parallel to g_lMenuNames, each entry containing a pipe-delimited string with the items for the corresponding menu
list g_lMenuPrompts = [
"\n\nWelcome to the Main Menu\nOpenNC Version 3.961",
"\n\nFrom here you can\nFix Menu's,\nGet a cuffs Help notecard,\nGet a link in local chat to join the support group.",
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
string UPDATE = "Update";
key wearer;

//size adust
float MIN_DIMENSION=0.001; // the minimum scale of a prim allowed, in any dimension
float MAX_DIMENSION=1.0; // the maximum scale of a prim allowed, in any dimension
float max_scale;
float min_scale;
float   cur_scale = 1.0;
integer handle;
integer menuChan;
float min_original_scale=10.0; // minimum x/y/z component of the scales in the linkset
float max_original_scale=0.0; // minimum x/y/z component of the scales in the linkset
list link_scales = [];
list link_positions = [];
 
makeMenu()
{
    llDialog(llGetOwner(),"Max scale: "+(string)max_scale+"\nMin scale: "+(string)min_scale+"\n \nCurrent scale: "+
        (string)cur_scale,["-0.01","-0.05","MIN  SIZE","+0.01","+0.05","MAX  SIZE","-0.10","-0.25","RESTORE","+0.10","+0.25"],menuChan);
}
 
integer scanLinkset()
{
    integer link_qty = llGetNumberOfPrims();
    integer link_idx;
    vector link_pos;
    vector link_scale;
    //script made specifically for linksets, not for single prims
    if (link_qty > 1)
    {
        //link numbering in linksets starts with 1
        for (link_idx=1; link_idx <= link_qty; link_idx++)
        {
            link_pos=llList2Vector(llGetLinkPrimitiveParams(link_idx,[PRIM_POSITION]),0);
            link_scale=llList2Vector(llGetLinkPrimitiveParams(link_idx,[PRIM_SIZE]),0);
            // determine the minimum and maximum prim scales in the linkset,
            // so that rescaling doesn't fail due to prim scale limitations
            if(link_scale.x<min_original_scale) min_original_scale=link_scale.x;
            else if(link_scale.x>max_original_scale) max_original_scale=link_scale.x;
            if(link_scale.y<min_original_scale) min_original_scale=link_scale.y;
            else if(link_scale.y>max_original_scale) max_original_scale=link_scale.y;
            if(link_scale.z<min_original_scale) min_original_scale=link_scale.z;
            else if(link_scale.z>max_original_scale) max_original_scale=link_scale.z;
            link_scales    += [link_scale];
            link_positions += [(link_pos-llGetRootPosition())/llGetRootRotation()];
        }
    }
    else
    {
        llOwnerSay("error: this script doesn't work for non-linked objects");
        return FALSE;
    }
    max_scale = MAX_DIMENSION/max_original_scale;
    min_scale = MIN_DIMENSION/min_original_scale;
    return TRUE;
}
 
resizeObject(float scale)
{
    integer link_qty = llGetNumberOfPrims();
    integer link_idx;
    vector new_size;
    vector new_pos;
    if (link_qty > 1)
    {
        //link numbering in linksets starts with 1
        for (link_idx=1; link_idx <= link_qty; link_idx++)
        {
            new_size   = scale * llList2Vector(link_scales, link_idx-1);
            new_pos    = scale * llList2Vector(link_positions, link_idx-1);
 
            if (link_idx == 1)
            {
                //because we don't really want to move the root prim as it moves the whole object
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size]);
            }
            else
            {
                llSetLinkPrimitiveParamsFast(link_idx, [PRIM_SIZE, new_size, PRIM_POSITION, new_pos]);
            }
        }
    }
}
//end of size adjust

integer getPersonalChannel(key owner, integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)owner,2,7)) + nOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}

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
        else lUtility = ["Collar Menu"];
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
    wearer = llGetOwner();
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
    HandleMenuResponse("Help/About|" + REFRESH_MENU);      
    HandleMenuResponse("Help/About|" + USER_GROUP);
    HandleMenuResponse("Help/About|" + helpcard);
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Main", "");
    //resize
    llListenRemove(handle);
    menuChan = 50000 + (integer)llFrand(50000.00);
    handle = llListen(menuChan,"",llGetOwner(),""); 
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
    else if (sStr == "cabout") Menu("Help/About", kID, iNum);
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
        if (scanLinkset()) { // llOwnerSay("resizer script ready");
        }
        
    }
    //-------extra cuff---------------
    touch_start(integer num)//so we can touch the cuff
    {
        key id = llDetectedKey(0);
        if ((llGetAttached() == 0)&& (id==wearer)) // If not attached then wake up update script then do nothing
        {
            llSetScriptState("OpenNC - update",TRUE);
            return;
        }
        
        if (llDetectedKey(0) == llGetOwner())// if we are wearer then allow to resize
        {
            llDialog(llGetOwner(),"Select if you want to Resize this item or the main Cuff Menu ",["Resizer","Cuff Menu"],menuChan);
        }
        else { llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "cmenu", llDetectedKey(0));}//else just give cuff menu
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
                    Menu("Help/About", kAv, iAuth);
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
                else if (sMessage == "Collar Menu")
                {
                    llRegionSayTo(wearer,getPersonalChannel(wearer,1111), (string)wearer + ":menu|"+(string)kAv);
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
    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        if (keyID == llGetOwner())
        {
            if (szMsg == "Cuff Menu")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "cmenu", keyID);
            }
            else if (szMsg == "Resizer")
            {
                makeMenu();
            }
            else
            {
                if (szMsg == "RESTORE")
                {
                    cur_scale = 1.0;
                }
                else if (szMsg == "MIN SIZE")
                {
                    cur_scale = min_scale;
                }
                else if (szMsg == "MAX SIZE")
                {
                    cur_scale = max_scale;
                }          
                else
                {
                    cur_scale += (float)szMsg;
                }
                //check that the scale doesn't go beyond the bounds
                if (cur_scale > max_scale)
                { 
                    cur_scale = max_scale;
                }
                if (cur_scale < min_scale)
                {
                    cur_scale = min_scale;
                }
                resizeObject(cur_scale);
                makeMenu();
            }
        }
    }
}