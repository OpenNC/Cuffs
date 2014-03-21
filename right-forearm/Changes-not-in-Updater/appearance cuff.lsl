////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - appearance cuff                            //
//                                 version 3.951                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not supported by OpenCollar at all
////////////////////////////////////////////////////////////////////////////////////

string g_sSubMenu = "Appearance";
string g_sParentMenu = "Main";
list g_lMenuIDs;//3-strided list of avkey, dialogid, menuname
integer g_iMenuStride = 3;
list g_lButtons = ["Chains"];
list g_lPrimStartSizes; // area for initial prim sizes (stored on rez)
integer g_iScaleFactor = 100; // the size on rez is always regarded as 100% to preven problem when scaling an item +10% and than - 10 %, which would actuall lead to 99% of the original size
integer g_iSizedByScript = FALSE; // prevent reseting of the script when the item has been chnged by the script
string TICKED = "☒ ";
string UNTICKED = "☐ ";
string APPLOCK = "LooksLock";
integer g_iAppLock = FALSE;
string g_sAppLockToken = "Appearance_Lock";
// OpenCuffs: Chains instead of Pos or Rot
list localbuttons = ["Chains"];
// name of buttons for the different chains in the chain  menu
list ChainMenuButtons = [   "Thin Gold",
                            "OC Standard",
                            "Pink Chain",
                            "Black Chain",
                            "Rope",
                            "Micro Black",
                            "Brass",
                            "Gold"
                            ];
// LG command sequence to be send
list ChainMenuCommands = [  "texture 6993a4d6-9155-d5cd-8434-a009b822d5a0 size 0.08 0.08 life 1 gravity 0.3",
                            "texture 245ea72d-bc79-fee3-a802-8e73c0f09473 size 0.07 0.07 life 1 gravity 0.3",
                            "texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.8 0.0 0.8",
                            "texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.1 0.1 0.1",
                            "texture 9de57a7d-b9d7-1b11-9be7-f0a42651755e size 0.07 0.07 life 0.5 gravity 0.3",
                            "texture fcb23dcf-c923-7226-2cbd-10f585597bfb size 0.07 0.07 life 0.5 gravity 0.3",
                            "texture 5cd418e9-9021-24b1-5a34-765d71cce566 size 0.07 0.07 life 0.5 gravity 0.3",
                            "texture 4cde01ac-4279-2742-71e1-47ff81cc3529 size 0.07 0.07 life 0.5 gravity 0.3"
                            ];
// Currenlty used default for chains, has to be resubmitted on every rez of a cuff
integer ChainCurrent = -1;
// Token for saving
string chaintoken = "chaindefault";
key g_keyChainDialogID;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer LM_CUFF_CHAINTEXTURE = -551003;   // used as channel for linkedmessages - sending the choosen texture to the cuff

string UPMENU = "BACK";
key g_kWearer;

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
} 

integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;
    if (iChan>0)
    {
        iChan=iChan*(-1);
    }
    if (iChan > -10000)
    {
        iChan -= 30000;
    }
    return iChan;
}
Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else if (llGetAgentSize(kID) != ZERO_VECTOR)
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
    else // remote request
    {
        llRegionSayTo(kID, GetOwnerChannel(g_kWearer, 1111), sMsg);
    }
}


SendDefChainCommand()
{
    string s;
    if ((ChainCurrent>=0) && (ChainCurrent<llGetListLength(ChainMenuButtons)))
    {
        s=llList2String(ChainMenuCommands,ChainCurrent);
    }
    else
    {
        s="";
    }
    llMessageLinked(LINK_SET,LM_CUFF_CHAINTEXTURE,s,NULL_KEY);
}

ChainMenu(key id, integer iAuth)
{
    string prompt = "Choose the standard chains for the collar.\nUse 'Resend' to resend the chain standards if they got out of sync (due to lag or asyncronus attaching). \nCurrent Chain: ";
    if (ChainCurrent==-1)
    {
        prompt+="Default from cuff";
    }
    else if ((ChainCurrent>=0) && (ChainCurrent<llGetListLength(ChainMenuButtons)))
    {
        prompt+=llList2String(ChainMenuButtons,ChainCurrent);
    }
    else // THis should hopefully not happen
    {
        prompt+="Undefined, please choose a new standard texture!";
        ChainCurrent=-1;
    }
    list mybuttons = ChainMenuButtons+["Resend"];
    g_keyChainDialogID = Dialog(id, prompt, mybuttons, [UPMENU], 0, iAuth);

}

string GetScriptID()
{
    // strip away "OpenCollar - " leaving the script's individual name
    list parts = llParseString2List(llGetScriptName(), ["-"], []);
    return llStringTrim(llList2String(parts, 1), STRING_TRIM) + "_";
}
string PeelToken(string in, integer slot)
{
    integer i = llSubStringIndex(in, "_");
    if (!slot) return llGetSubString(in, 0, i);
    return llGetSubString(in, i + 1, -1);
}

DoMenu(key kAv, integer iAuth)
{
    list lMyButtons;
    string sPrompt;
    if (g_iAppLock)
    {
        sPrompt = "\n\nThe appearance of the collar has been locked.\nAn owner must unlock it to allow modification.";
        lMyButtons = [TICKED + APPLOCK];
    }
    else
    {
        sPrompt = "\n\nChange looks, adjustment and size.\n\nAdjustments are based on the neck attachment spot.";
    
        lMyButtons = [UNTICKED + APPLOCK];
        lMyButtons += llListSort(g_lButtons, 1, TRUE);
    }
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0, iAuth);
    integer iMenuIndex = llListFindList(g_lMenuIDs, [kAv]);
    list lAddMe = [kAv, kMenuID, g_sSubMenu];
    if (iMenuIndex == -1)
    {
        g_lMenuIDs += lAddMe;
    }
    else
    {
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, lAddMe, iMenuIndex, iMenuIndex + g_iMenuStride - 1);    
    }    
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
    }
    
    on_rez(integer iParam)
    {
        llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == MENUNAME_RESPONSE)
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sCommand == "menu" && llGetSubString(sStr, 5, -1) == g_sSubMenu)
            {//someone asked for our menu
                //give this plugin's menu to id
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the cuff's appearance.", FALSE);
                    llMessageLinked(LINK_SET, iNum, "menu " + g_sParentMenu, kID);
                }
                else DoMenu(kID, iNum);
            }
            else if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == "appearance")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the cuff's appearance.", FALSE);
                }
                else DoMenu(kID, iNum);
            }
            else if (sCommand == "lockappearance")
            {
                if (iNum == COMMAND_OWNER)
                {
                    g_iAppLock = (sValue!="0");
                    if(g_iAppLock) llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sAppLockToken + "=1", NULL_KEY);
                    else llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sAppLockToken, NULL_KEY);
                }
                else Notify(kID,"Only owners can use this option.", FALSE);
            }
            else if ((sStr == "menu Chains")||(sStr == "chains"))
            {
                ChainMenu(kID, iNum);
            }
            else if (sStr == "Resync Cuffs")
            {
                SendDefChainCommand();
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"resend_appearance", kID);
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);

            if (sToken == g_sAppLockToken)
            {
                g_iAppLock = (integer)sValue;
            }
            
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["|"], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {//got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                               
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                  
                if (sMenuType == g_sSubMenu)
                {
                    if (sMessage == UPMENU)
                    {//give kID the parent menu
                        llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
                    }
                    else if(llGetSubString(sMessage, llStringLength(TICKED), -1) == APPLOCK)
                    {
                        integer lock = llGetSubString(sMessage, 0, llStringLength(UNTICKED) - 1) == UNTICKED;
                        if (iAuth == COMMAND_OWNER) g_iAppLock = lock;
                        // /Hack
                        if (lock) llMessageLinked(LINK_SET, iAuth, "lockappearance 1", kAv);
                        else llMessageLinked(LINK_SET, iAuth, "lockappearance 0", kAv);
                        DoMenu(kAv, iAuth);
                    }
                    else if (~llListFindList(g_lButtons, [sMessage]))
                    {//we got a submenu selection
                        llMessageLinked(LINK_SET, iAuth, "menu " + sMessage, kAv);
                    }                                
                }
            }
            if (sToken == chaintoken)
            {
                ChainCurrent = (integer)sValue;
                SendDefChainCommand();
            }
             else if(kID == g_keyChainDialogID)
            {
                list menuparams = llParseString2List(sStr, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer iAuth = (integer)llList2String(menuparams, 3);

                if (message == UPMENU)
                {
                    DoMenu(AV, iAuth);
                    return;
                }
                else if (~llListFindList(ChainMenuButtons, [message]))
                {
                    ChainCurrent=llListFindList(ChainMenuButtons, [message]);
                    SendDefChainCommand();
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, chaintoken + "=" + (string)ChainCurrent, NULL_KEY);
                    ChainMenu(AV, iAuth);
                }
                else if (message=="Resend")
                {
                    SendDefChainCommand();
                    ChainMenu(AV, iAuth);
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {//remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                          
            }            
        }
    } 
    
    timer()
    {// the timer is needed as the changed_size even is triggered twice
        llSetTimerEvent(0);
        if (g_iSizedByScript)
            g_iSizedByScript = FALSE;
    }
}