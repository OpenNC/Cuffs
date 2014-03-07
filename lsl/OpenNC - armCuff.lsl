////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - armcuff                                    //
//                            version 3.950                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////
string parentmenu = "Main";
string submenu = "Cuff Poses";
string dbtoken = "cuffmenu";
string CLCMD = "cpose";
list localbuttons = ["Stop all"]; //["Arms", "Legs", "Stop all"];
list buttons;
// stay mode when legs are cuffed
string  g_szStayModeFixed = "Stay: Fixed";
string  g_szStayModeSlow = "Stay: Slow";
string  g_szStayModeFree = "Stay: Free";
string  g_szStayModeToken1 = "stay";
integer g_nStayModeFixed = FALSE; // instead of false we use a very high value
integer g_nStayModeAuth = FALSE; // instead of false we use a very high value
// RLV restriction when chained
string  g_szRLVModeEnabled = "(*) RLV Restricions";
string  g_szRLVModeDisabled = "( ) RLV Restricions";
string  g_szRLVModeToken = "rest";
integer g_nRLVModeAuth = FALSE;
integer g_nRemenu = FALSE;
key g_keyDialogID;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
string UPMENU = "BACK";
//===============================================================================
// AK - Cuff - functions & variables
//===============================================================================
string    g_szModToken    = "rlac";         // valid token for this module
integer    LM_CUFF_CMD        = -551001;        // used as channel for linkemessages - sending commands
key        g_keyWearer        = NULL_KEY;        // key of the owner/wearer
//===============================================================================
// END AK - Cuff - functions & variables
//===============================================================================
//===============================================================================
//= parameters   :   none
//=
//= return        :    string prefix for the object in the form of "oc_"
//=
//= description  :    generate the prefix from the object desctiption
//=
//===============================================================================
string szGetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}
//===============================================================================
//= parameters   :    key keyID   Target for the message
//=                string szMsg   Message to SEND
//=                integer nAlsoNotifyWearer Boolean to notify the wearer as well
//=
//= return        :    none
//=
//= description  :    send a message to a receiver and if needed to the wearer as well
//=
//===============================================================================
Notify(key keyID, string szMsg, integer nAlsoNotifyWearer)
{
    if (keyID == g_keyWearer)
    {
        llOwnerSay(szMsg);
    }
    else
    {
        llInstantMessage(keyID,szMsg);
        if (nAlsoNotifyWearer)
        {
            llOwnerSay(szMsg);
        }
    }
}

key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string chars = "0123456789abcdef";
    integer length = 16;
    string out;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer index = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        out += llGetSubString(chars, index, index);
    }
    return (key)(out + "-0000-0000-0000-000000000000");
}

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

DoMenu(key id)
{
    string prompt = "Pick an option.";
    list mybuttons = llListSort(localbuttons + buttons, 1, TRUE);
    if (g_nStayModeAuth>0)
    {
        if (g_nStayModeFixed)
        {
            mybuttons += [g_szStayModeFixed];
        }
        else
        {
            mybuttons += [g_szStayModeSlow];
        }
    }
    else
    {
        mybuttons += [g_szStayModeFree];
    }

    if (g_nRLVModeAuth>0)
    {
        mybuttons += [g_szRLVModeEnabled];
    }
    else
    {
        mybuttons += [g_szRLVModeDisabled];
    }
    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}
//===============================================================================
//= parameters   :    list    lstIn   list of menu buttons
//=
//= return        :   list    updated list of menu buttons
//=
//= description  :    resort menu button top to do and fills the menu to be user finldy
//=
//===============================================================================
integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

init()
{
    g_keyWearer = llGetOwner();
    llMessageLinked(LINK_SET, LM_CUFF_CMD, "settoken=" + g_szModToken, g_keyWearer);
    g_szStayModeToken1=szGetDBPrefix() + g_szStayModeToken1;
    g_szRLVModeToken=szGetDBPrefix() + g_szRLVModeToken;
    llSleep(1.0);
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
}

default
{
    state_entry()
    {
        init();
    }
    
    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if ( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
        }
        else
        { //owner, secowner, group, and wearer may currently change colors
            if (szMsg == "reset" && (nNum == COMMAND_OWNER || nNum == COMMAND_WEARER))
            { //clear saved settings
                llResetScript();
            }
            else if (nNum >= COMMAND_OWNER && nNum <= COMMAND_WEARER)
            {
                if (szMsg == "refreshmenu")
                {
                    buttons = [];
                    llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
                }
                else if (startswith(szMsg,"staymode"))
                {
                    if ((g_nStayModeAuth!=0)&&(g_nStayModeAuth<nNum))
                    {
                        Notify(keyID,"You are not allowed to change the stay mode.",FALSE);
                    }
                    else if (szMsg=="staymode=off")
                    {// disable the stay mode
                        g_nStayModeAuth=FALSE;
                        llMessageLinked(LINK_SET, LM_CUFF_CMD, "staymode=off", NULL_KEY);
                        Notify(keyID,llKey2Name(g_keyWearer)+ " will now be able to move, even when the legs are bound.", TRUE);
                    }
                    else if (szMsg=="staymode=slow")
                    {// enable the slow mode
                        g_nStayModeAuth=nNum;
                        g_nStayModeFixed=FALSE;
                        llMessageLinked(LINK_SET, LM_CUFF_CMD, "staymode=slow", NULL_KEY);
                        Notify(keyID,llKey2Name(g_keyWearer)+ " will now only able to move very slowly, when the legs are bound.", TRUE);
                    }
                    else if (szMsg=="staymode=on")
                    {// enable the stay mode
                        g_nStayModeAuth=nNum;
                        g_nStayModeFixed=TRUE;
                        llMessageLinked(LINK_SET, LM_CUFF_CMD, "staymode=on", NULL_KEY);
                        Notify(keyID,llKey2Name(g_keyWearer)+ " will now NOT be able to move, when the legs are bound.", TRUE);
                    }
                    if (g_nRemenu)
                    {
                        g_nRemenu=FALSE;
                        DoMenu(keyID);
                    }
                }
                else if (szMsg=="rlvmode=off")
                {// disable the stay mode
                    if (g_nRLVModeAuth>=nNum)
                    {
                        g_nRLVModeAuth=FALSE;
                        llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvmode=off", NULL_KEY);
                        Notify(keyID,llKey2Name(g_keyWearer)+ " will now NOT be under RLV restrictions when bound.", TRUE);
                    }
                    else
                    {
                        Notify(keyID,"You are not allowed to change the restriction mode.",FALSE);
                    }
                    if (g_nRemenu)
                    {
                        g_nRemenu=FALSE;
                        DoMenu(keyID);
                    }
                }
                else if (szMsg=="rlvmode=on")
                {// enable the stay mode
                    g_nRLVModeAuth=nNum;
                    llMessageLinked(LINK_SET, LM_CUFF_CMD, "rlvmode=on", NULL_KEY);
                    Notify(keyID,llKey2Name(g_keyWearer)+ " will now be under RLV restrictions when bound.", TRUE);
                    if (g_nRemenu)
                    {
                        g_nRemenu=FALSE;
                        DoMenu(keyID);
                    }
                }
            }
            else if (nNum == MENUNAME_REQUEST)
            {
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            }
            else if (nNum == MENUNAME_RESPONSE)
            {
                list parts = llParseString2List(szMsg, ["|"], []);
                if (llList2String(parts, 0) == submenu)
                {//someone wants to stick something in our menu
                    string button = llList2String(parts, 1);
                    if (llListFindList(buttons, [button]) == -1)
                    {
                        buttons = llListSort(buttons + [button], 1, TRUE);
                    }
                }
            }
            if ((nNum >= COMMAND_OWNER && nNum <= COMMAND_WEARER) && szMsg == "menu Cuff Poses")
            {
                DoMenu(keyID);
            }
            else if (nNum == COMMAND_SAFEWORD)
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "*:Stop", keyID);
            }
            else if (nNum == DIALOG_RESPONSE)
            {
                    g_nRemenu = FALSE;
                    list menuparams = llParseString2List(szMsg, ["|"], []);
                    key AV = (key)llList2String(menuparams, 0);
                    string message = llList2String(menuparams, 1);
                    integer page = (integer)llList2String(menuparams, 2);
                    integer iAuth = (integer)llList2String(menuparams, 3); // auth level of avatar

                    if ((message == UPMENU) && (g_keyDialogID == keyID))
                    {
                        llMessageLinked(LINK_SET, iAuth, "menu "+ parentmenu, AV);//NEW command structer
                    }
                    else if (~llListFindList(localbuttons, [message]))
                    {
                        if ( message == "Stop all" )
                        {
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "*:Stop", AV);
                            // Cleo: Call the menu again
                            DoMenu(AV);
                        }
                    }
                    else if (~llListFindList(buttons, [message]))
                    { //we got a submenu selection
                        llMessageLinked(LINK_SET, SUBMENU, message, AV);
                    }
                    else if (message==g_szStayModeFixed)
                    {// disable the stay mode
                        g_nRemenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "staymode=off", AV);
                    }
                    else if (message==g_szStayModeSlow)
                    {// disable the stay mode
                        g_nRemenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "staymode=on", AV);
                    }
                    else if (message==g_szStayModeFree)
                    {// enable the stay mode
                        g_nRemenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "staymode=slow", AV);
                    }
                    else if (message==g_szRLVModeEnabled)
                    {// disable the stay mode
                        g_nRemenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rlvmode=off", AV);
                    }
                    else if (message==g_szRLVModeDisabled)
                    {// enable the stay mode
                        g_nRemenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rlvmode=on", AV);
                    }
            }
            else if (szMsg == CLCMD)
            {
                DoMenu(keyID);
            }
        }
    }

    changed(integer change)
    {
        if (change==CHANGED_OWNER)
        {
            llMessageLinked(LINK_SET, LM_CUFF_CMD, "reset", NULL_KEY);
        }
    }
    on_rez(integer change)//lets do a reset on new owner
    {
        if (g_keyWearer!=llGetOwner())
        {
            llResetScript(); //left in so it clears on new owner
        }
    }
}