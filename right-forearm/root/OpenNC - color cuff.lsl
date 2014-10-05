////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - color cuff                                 //
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
//on getting color command, give menu to choose which element, followed by menu to pick color
list g_lColorSettings;
string g_sParentMenu = "Appearance";
string g_sSubMenu = "Colors";
string CLCMD = "ccolors";
list g_lColors;
integer g_iStridelength = 2;
integer g_iLength;
list g_lButtons;
list g_lNewButtons;
list g_lMenuIDs;
key g_kTouchID;
integer g_iAppLock = FALSE;
string g_sAppLockToken = "Appearance_Lock";

//MESSAGE MAP
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer NOTIFY = 550;
integer SENDCMD= 551;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer TOUCH_REQUEST = -9500;
integer TOUCH_RESPONSE = -9502;
string UPMENU = "BACK";
string CTYPE = "cuffs";
key g_kWearer;
string g_sScript;

list g_lElements;
string g_sCurrentElement = "";
string g_sCurrentCategory = "";
list g_lCategories = ["Shades", "Bright", "Soft"];

list g_lAllColors = [
"Light Shade|<0.82745, 0.82745, 0.82745>
Gray Shade|<0.70588, 0.70588, 0.70588>
Dark Shade|<0.20784, 0.20784, 0.20784>
Brown Shade|<0.65490, 0.58431, 0.53333>
Red Shade|<0.66275, 0.52549, 0.52549>
Blue Shade|<0.64706, 0.66275, 0.71765>
Green Shade|<0.62353, 0.69412, 0.61569>
Pink Shade|<0.74510, 0.62745, 0.69020>
Gold Shade|<0.69020, 0.61569, 0.43529>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>",
"Magenta|<1.00000, 0.00000, 0.50196>
Pink|<1.00000, 0.14902, 0.50980>
Hot Pink|<1.00000, 0.05490, 0.72157>
Firefighter|<0.88627, 0.08627, 0.00392>
Sun|<1.00000, 1.00000, 0.18039>
Flame|<0.92941, 0.43529, 0.00000>
Matrix|<0.07843, 1.00000, 0.07843>
Electricity|<0.00000, 0.46667, 0.92941>
Violet Wand|<0.63922, 0.00000, 0.78824>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>",
"Baby Blue|<0.75686, 0.75686, 1.00000>
Baby Pink|<1.00000, 0.52157, 0.76078>
Rose|<0.93333, 0.64314, 0.72941>
Beige|<0.86667, 0.78039, 0.71765>
Earth|<0.39608, 0.27451, 0.18824>
Ocean|<0.25882, 0.33725, 0.52549>
Yolk|<0.98824, 0.73333, 0.29412>
Wasabi|<0.47059, 1.00000, 0.65098>
Lavender|<0.89020, 0.65882, 0.99608>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>"
];

//integer g_nCmdChannel    = -190890;
//integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for
string  g_szModToken = "rlac"; // valid token for this module
string g_szColorChangeCmd ="ColorChanged"; // Comand for Cuffs to change the colors
/*
integer nGetOwnerChannel(integer nOffset)//Lets get out channel number
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
    if (chan>0)
        chan=chan*(-1);
    if (chan > -10000)
        chan -= 30000;
    return chan;
}
*/
SendCmd( string szSendTo, string szCmd, key keyID )
{
//    llRegionSayTo(g_kWearer,g_nCmdChannel + 1, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);//lets send the command on our channel + 1
     llMessageLinked( LINK_SET, SENDCMD, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID, keyID);
}

string szStripSpaces (string szStr)
{
    return llDumpList2String(llParseString2List(szStr, [" "], []), "");
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
} 

key TouchRequest(key kRCPT,  integer iTouchStart, integer iTouchEnd, integer iAuth)
{
    key kID = llGenerateKey();
    integer iFlags = 0;
    if (iTouchStart) iFlags = iFlags | 0x01;
    if (iTouchEnd) iFlags = iFlags | 0x02;
    llMessageLinked(LINK_SET, TOUCH_REQUEST, (string)kRCPT + "|" + (string)iFlags + "|" + (string)iAuth, kID);
    return kID;
} 
/*
Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
        llOwnerSay(sMsg);
    else
    {
        if (llGetAgentSize(kID) != ZERO_VECTOR)
            llRegionSayTo(kID,0,sMsg);
        else
            llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer)
            llOwnerSay(sMsg);
    }
}
*/
CategoryMenu(key kAv, integer iAuth)
{ //give kAv a dialog with a list of color cards
    string sPrompt = "\n\nSelect a color catagory.\n";
    g_lMenuIDs+=[Dialog(kAv, sPrompt, g_lCategories, [UPMENU],0, iAuth)];
}

ColorMenu(key kAv, integer iAuth)
{
    string sPrompt = "\n\nChoose a color.\n";
    list g_lButtons = llList2ListStrided(g_lColors,0,-1,2);
    g_lMenuIDs+=[Dialog(kAv, sPrompt, g_lButtons, [UPMENU],0, iAuth)];
}

ElementMenu(key kAv, integer iAuth)
{
    string sPrompt = "\n\nWhich element of the " + CTYPE + " would you like to tint?\n\nChoose *Touch* if you want to select the part by directly clicking on the " + CTYPE + ".";
    g_lButtons = llListSort(g_lElements, 1, TRUE);
    g_lMenuIDs+=[Dialog(kAv, sPrompt, g_lButtons, ["*Touch*", UPMENU],0, iAuth)];
}

string ElementType(integer iLinkNumber)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(iLinkNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, ["nocolor"])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
        return "nocolor";
    else
        return llList2String(lParams, 0);
}

BuildElementList()
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    for (n = 2; n <= iLinkCount; n++)//root prim is 1, so start at 2
    {
        string sElement = ElementType(n);
        if (!(~llListFindList(g_lElements, [sElement])) && sElement != "nocolor")
            g_lElements += [sElement];
    }
}

SetElementColor(string sElement, vector vColor)
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    for (n = 2; n <= iLinkCount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == sElement) //set link to new color
            llSetLinkColor(n, vColor, ALL_SIDES);
    }
    //create shorter string from the color vectors before saving
    string sStrColor = Vec2String(vColor);
    //change the g_lColorSettings list entry for the current element
    integer iIndex = llListFindList(g_lColorSettings, [sElement]);
    if (iIndex == -1)
        g_lColorSettings += [sElement, sStrColor];
    else
        g_lColorSettings = llListReplaceList(g_lColorSettings, [sStrColor], iIndex + 1, iIndex + 1);
    //save to settings
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sScript + sElement + "=" + sStrColor, "");
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

string Vec2String(vector vVec)
{
    list lParts = [vVec.x, vVec.y, vVec.z];
    integer n;
    for (n = 0; n < 3; n++)
    {
        string sStr = llList2String(lParts, n);
        //remove any trailing 0's or .'s from sStr
        while ((~(integer)llSubStringIndex(sStr, ".")) && (llGetSubString(sStr, -1, -1) == "0" || llGetSubString(sStr, -1, -1) == "."))
            sStr = llGetSubString(sStr, 0, -2);
        lParts = llListReplaceList(lParts, [sStr], n, n);
    }
    return "<" + llDumpList2String(lParts, ",") + ">";
}

default
{
    state_entry()
    {
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer = llGetOwner();
        BuildElementList();//loop through non-root prims, build element list
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
//        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        string sMsg2;
        string sMsg3;
        list lParams1 = llParseString2List(sStr, ["_"], []);
        sMsg2 = llList2String(lParams1, 0);
        sMsg3 = llList2String(lParams1, 1);
        if (sMsg2 =="color")
        {
    // A change of color has occured, make sure the cuff will try to set identical to the collar
            list lParams2 = llParseString2List(sMsg3, ["="], []);
            SendCmd("*",g_szColorChangeCmd+"=" + sMsg3,"");//send color change to other cuffs
            SetElementColor(llList2String(lParams2,0),(vector)szStripSpaces(llList2String(lParams2,1))); //send the color change to this cuff
        }
        if (sStr == "reset" && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
        {//clear saved settings
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sScript + "all", "");
            llResetScript();
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            if (sStr == "settings")
            {
                string out;
                integer i = 0;
                for (; i < llGetListLength(g_lColorSettings); i += 2)
                {
                    if (i != 0) out += ",";
                    out += llList2String(g_lColorSettings, i) + "=";
                    out += llList2String(g_lColorSettings, i + 1);
                }
//                Notify(kID, "Color Settings: " + out,FALSE);
                llMessageLinked(LINK_SET, NOTIFY, "Color Settings: " + out + " |FALSE",kID);
            }
            else if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
            }
            else if (StartsWith(sStr, "setcolor"))
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
//                    Notify(kID,"You are not allowed to change the colors.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You are not allowed to change the colors.|FALSE",kID);
                else if (g_iAppLock)
//                    Notify(kID,"The appearance of the " + CTYPE + " is locked. You cannot access this menu now!", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "The appearance of the " + CTYPE + " is locked. You cannot access this menu now!|FALSE",kID);
                else
                {
                    list lParams = llParseString2List(sStr, [" "], []);
                    string sElement = llList2String(lParams, 1);
                    lParams = llParseString2List(sStr, ["<"], []);
                    vector vColor = (vector)("<"+llList2String(lParams, 1));
                    SetElementColor(sElement, vColor);
                }
            }
            else if (sStr == "menu "+ g_sSubMenu || sStr == "ccolors")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
//                    Notify(kID,"You are not allowed to change the colors.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You are not allowed to change the colors.|FALSE",kID);
                    llMessageLinked(LINK_SET, iNum, "clooks", kID);
                }
                else if (g_iAppLock)
                {
//                    Notify(kID,"The appearance of the " + CTYPE + " is locked. You cannot access this menu now!", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "The appearance of the " + CTYPE + " is locked. You cannot access this menu now!|FALSE",kID);
                    llMessageLinked(LINK_SET, iNum, "clooks", kID);
                }
                else
                {
                    g_sCurrentElement = "";
                    ElementMenu(kID, iNum);
                }
            }
            else if (llGetSubString(sStr,0,13) == "lockappearance")
            {
                if (iNum == COMMAND_OWNER)
                {
                    if(llGetSubString(sStr, -1, -1) == "0")
                        g_iAppLock  = FALSE;
                    else
                        g_iAppLock  = TRUE;
                }
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            integer i = llSubStringIndex(sStr, "=");
            string sToken = llGetSubString(sStr, 0, i - 1);
            string sValue = llGetSubString(sStr, i + 1, -1);
            i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sScript)
            {
                sToken = llGetSubString(sToken, i + 1, -1);
                SetElementColor(sToken, (vector)sValue);
            }
            else if (sToken == g_sAppLockToken)
                g_iAppLock = (integer)sValue;
            else if (sToken == "Global_CType") CTYPE = sValue;
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {
                g_lMenuIDs=llDeleteSubList(g_lMenuIDs,iMenuIndex,iMenuIndex);
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMessage == UPMENU)
                {
                    if (g_sCurrentElement == "")//main menu
                        llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                    else if (g_sCurrentCategory == "")
                    {
                        g_sCurrentElement = "";
                        ElementMenu(kAv, iAuth);
                    }
                    else
                    {
                        g_sCurrentCategory = "";
                        CategoryMenu(kAv, iAuth);
                    }
                }
                else if (sMessage == "*Touch*")
                {
//                    Notify(kAv, "Please touch the part of the " + CTYPE + " you want to recolor.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "Please touch the part of the " + CTYPE + " you want to recolor.|FALSE",kAv);
                    g_kTouchID = TouchRequest(kAv, TRUE, FALSE, iAuth);
                }
                else if (g_sCurrentElement == "")
                { //we just got the element name
                    g_sCurrentElement = sMessage;
                    g_sCurrentCategory = "";
                    CategoryMenu(kAv, iAuth);
                }
                else if (g_sCurrentCategory == "")
                {
                    g_lColors = [];
                    g_sCurrentCategory = sMessage;
                    integer iIndex = llListFindList(g_lCategories,[sMessage]);
                    //sDatakID = llGetNotecardLine("colors-" + g_sCurrentCategory, g_iLine);
                    //we'll have gotten several lines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                    //parse that into 2-strided list of colorname, colorvector
                    g_lColors = llParseString2List(llList2String(g_lAllColors, iIndex), ["\n", "|"], []);
                    g_lColors = llListSort(g_lColors, 2, TRUE);
                    ColorMenu(kAv,iAuth);
                }
                else if (~(integer)llListFindList(g_lColors, [sMessage]))
                { //found a color, now set it
                    integer iIndex = llListFindList(g_lColors, [sMessage]);
                    vector vColor = (vector)llList2String(g_lColors, iIndex + 1);
                    SetElementColor(g_sCurrentElement, vColor);
                    //send to other cuffs
                    SendCmd("*",g_szColorChangeCmd+"="+g_sCurrentElement+"="+(string)vColor,"");
                    ColorMenu(kAv, iAuth);
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
                g_lMenuIDs=llDeleteSubList(g_lMenuIDs,iMenuIndex,iMenuIndex);
        }
        else if (iNum == TOUCH_RESPONSE)
        {
            if (kID == g_kTouchID)
            {
                list lParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lParams, 0);
                integer iAuth = (integer)llList2String(lParams, 1);
                integer iLinkNumber = (integer)llList2String(lParams, 3);
                string sElement = ElementType(iLinkNumber);
                if (sElement != "nocolor")
                {
                    CategoryMenu(kAv, iAuth);
                    g_sCurrentElement = sElement;
//                    Notify(kAv, "You selected \""+sElement+"\".", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You selected \""+sElement+"\".|FALSE",kAv);
                }
                else
                {
//                    Notify(kAv, "You selected a prim which is not colorable. You can try again.", FALSE);
                    llMessageLinked(LINK_SET, NOTIFY, "You selected a prim which is not colorable. You can try again.|FALSE",kAv);
                    ElementMenu(kAv, iAuth);
                }
            }
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}