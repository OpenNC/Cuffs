////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - arms                                       //
//                            version 3.968                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////
list elements;
string parentmenu = "Cuff Poses";
string submenu = "Arm Cuffs";
string dbtoken = "cuff-arms";
string CLCMD = "carms";
string defaultscard = "Arm Cuffs";
string menupose;
list buttons;
integer lastrank = 10000; //in this integer, save the rank of the person who posed the av, according to message map.  10000 means unposed
key g_keyDialogID;
key g_keyWearer;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;//do we still need this?
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer LM_CUFF_CMD  = -551001;// used as channel for linkemessages - sending commands
integer LM_CUFF_ANIM = -551002;// used as channel for linkedmessages - sending animation cmds
integer LM_CUFF_CHAINTEXTURE = -551003;// used as channel for linkedmessages - sending the choosen texture to the cuff
list g_lstModTokens = ["rlac","orlac","irlac"]; // list of attachment points in this cuff, only need for the main cuff, so i dont want to read that from prims
string g_szLGChainTexture="";
string UPMENU = "BACK";
//===============================================================================
// AK - Cuff - functions & variables
//===============================================================================
string    g_szActAnim        = "";
integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for
list    g_lstLocks;
list    g_lstAnims;
list    g_lstChains;
integer pos_line;
string pos_file;
key pos_query;

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

LoadLocks(string file)
{
    pos_line = 0;
    pos_file = file;
    g_lstLocks = g_lstAnims = g_lstChains = [];
    LoadLocksNextLine();
}

LoadLocksNextLine()
{
    pos_query = llGetNotecardLine( pos_file, pos_line);
}

integer LoadLocksParse( key queryid, string data)
{
    if ( pos_query != queryid ) return 0;
    if ( data == EOF )
    {
        g_lstLocks = ["*Stop*"] + g_lstLocks;
        g_lstAnims = [""] + g_lstAnims;
        g_lstChains = [""] + g_lstChains;
        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, dbtoken, "");//lets make sure we get our pose back once notecard is read
        return -1;
    }
    pos_line ++;
    LoadLocksNextLine();

    if (llGetSubString(data,0,0)=="#")
    {// comment, no need to parse that
        return 1;
    }
    list lock = llParseString2List( data, ["|"], [] );
    if ( llGetListLength(lock) != 3 ) {
        return 1;
    }
    g_lstLocks += (list)llList2String(lock,0);
    g_lstAnims += (list)llList2String(lock,1);
    g_lstChains += (list)llList2String(lock,2);
    return 1;
}
//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
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
//===============================================================================
//= parameters   :    string    szSendTo    prefix of receiving modul
//=                    string    szCmd       message string to send
//=                    key        keyID        key of the AV or object
//=
//= retun        :    none
//=
//= description  :    Sends the command with the prefix and the UUID
//=                    on the command channel
//=
//===============================================================================
SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSayTo(g_keyWearer,g_nCmdChannel + 1, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string  szChain    chain info string
//=                 string  szLink  link or unlin the chain
//=
//= retun        :
//=
//= description  :    devides the chain string into single chain commands
//=                    delimiter = ~
//=                    single chains are redirected to Chains
//=
//===============================================================================
DoChains( key keyID, string szChain, string szLink )
{
    list    lstParsed = llParseString2List( szChain, [ "~" ], [] );
    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;
    for (i = 0; i < nCnt; i++ )
    {
        Chains(keyID, llList2String(lstParsed, i), szLink);
    }
    lstParsed = [];
}
//===============================================================================
//= parameters   :    string    szMsg    Lock name forced from calling AV
//=                    key        keyID    key of the calling AV
//=
//= retun        :    none
//=
//= description  :    Sends the Anim & chain LM with the ID of the calling AV
//=
//===============================================================================
Chains(key keyID, string szChain, string szLink)
{
    list    lstParsed    = llParseString2List( szChain, [ "=" ], [] );
    string    szTo        = llList2String(lstParsed,0);
    string    szFrom        = llList2String(lstParsed,1);
    string    szCmd;
    if (szLink=="link")
    {
        if (g_szLGChainTexture=="")
        {
            szCmd="link";
        }
        else
        {
            szCmd="link "+g_szLGChainTexture;
        }
    }
    else
    {
        szCmd="unlink";
    }

    if ( llListFindList(g_lstModTokens,[szTo]) != -1 )
        llMessageLinked( LINK_SET, LM_CUFF_CMD, "chain=" + szChain + "=" + szCmd, llGetKey() );
    else
        SendCmd(szTo, "chain=" + szChain + "=" + szCmd, llGetKey());
}

CallAnim( string szMsg, key keyID )
{
    integer nIdx    = -1;
    string    szAnim    = "";
    string    szChain    = "";

        if ( g_szActAnim != "")
        nIdx    = llListFindList(g_lstLocks, [g_szActAnim]);
    if ( nIdx != -1 )
    {
        szChain    = llList2String(g_lstChains, nIdx);
        DoChains(keyID, szChain, "unlink");
    }
    if ( szMsg == "Stop" )
    {
        g_szActAnim = "";
        llMessageLinked( LINK_SET, LM_CUFF_ANIM, "a:Stop", keyID );
    }
    else
    {
        nIdx = llListFindList(g_lstLocks, [szMsg]);
        if (nIdx != -1 )
        {
            g_szActAnim = szMsg;
            szAnim    = llList2String(g_lstAnims, nIdx);
            szChain    = llList2String(g_lstChains, nIdx);
            llMessageLinked( LINK_SET, LM_CUFF_ANIM, "a:"+szAnim, keyID );  
            DoChains(keyID, szChain, "link");
        }
    }
}
//===============================================================================
// END AK - Cuff - Functions
//===============================================================================
DoMenu(key id)
{
    string prompt = "\nArm poses can be called from the chat line in the following format \n<pre>a:<Button_Name> ie- ora:Armsup";
    prompt += "\nCurrent pose is - " + menupose;
    list mybuttons = buttons + g_lstLocks;
    prompt += "\n\nPick an option.";
    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

default
{
    state_entry()
    {
        g_nCmdChannel= nGetOwnerChannel(g_nCmdChannelOffset);
        g_keyWearer=llGetOwner();
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, "");
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        if (llGetInventoryType(defaultscard) == INVENTORY_NOTECARD) //testing existance of notecard
        {
            LoadLocks(defaultscard);
        }
        else llOwnerSay (defaultscard + " notecard not found!");
        
    }
    dataserver( key queryid, string data ) 
    {
        if ( LoadLocksParse( queryid, data ) ) return;
    }
    changed(integer change) {
        if ( change & CHANGED_INVENTORY ) 
        {
            if (llGetInventoryType(defaultscard) == INVENTORY_NOTECARD) //testing existance of notecard
            {
                LoadLocks(defaultscard);
            }
            else llOwnerSay (defaultscard + " notecard not found!");
        }
    }

    link_message(integer sender, integer nNum, string str, key id)
    { //owner, secowner, group, and wearer may currently change colors
        if (str == "reset" && (nNum == COMMAND_OWNER || nNum == COMMAND_WEARER))
        { //clear saved settings
            llResetScript();
        }
        else if (nNum==LM_CUFF_CHAINTEXTURE)
        {
            g_szLGChainTexture=str;
            if (g_szActAnim!="")
            {
                CallAnim(g_szActAnim,llGetOwner());
            }
        }
        else if (nNum >= COMMAND_OWNER && nNum <= COMMAND_WEARER)
        {
            if ( startswith(str,"*:") || startswith(str,"a:") )
            {
                if (nNum <= lastrank)
                {
                    if (llGetSubString(str, 2,-1)=="Stop")
                    {
                        lastrank = 10000;
                    }
                    else
                    {
                        lastrank=nNum;
                    }
                    CallAnim(llGetSubString(str, 2,-1), id);
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"="+ llGetSubString(str, 2,-1), "");
                }
            }
            else if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, "");
            }
        }
        else if (nNum == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        }
        else if (nNum == SUBMENU && str == submenu)
        {
            DoMenu(id);
        }
        else if ( nNum == LM_CUFF_CMD )
        {
            string szToken = llGetSubString(str, 0,1);

            if ( str == "reset")
            {
                llResetScript();
            }
        }
        
        else if ( nNum == DIALOG_RESPONSE)
        {
            if (id==g_keyDialogID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                integer iAuth = (integer)llList2String(menuparams, 3); // auth level of avatar
                if (message == UPMENU)
                {
                    llMessageLinked(LINK_THIS, iAuth, "menu "+ parentmenu, AV);//NEW command structer
                }
                else if (~llListFindList(g_lstLocks, [message]))
                {
                    if (message=="*Stop*")
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "a:Stop", AV);
                        menupose = "none";
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "a:"+message, AV);
                        menupose = message;
                    }
                    DoMenu(AV);
                }
            }
        }
        else if (nNum == LM_SETTING_RESPONSE)
        {
            list menuparams = llParseString2List(str, ["="], []);
            string token = llList2String(menuparams, 0);
            string pose = llList2String(menuparams, 1);
            if(token == dbtoken)
            {
                CallAnim(pose, g_keyWearer);
                menupose = pose;
            }

        }
        else if (str == CLCMD)
        {
            DoMenu(id);
        }
    }

    on_rez(integer param)
    {
        if (g_keyWearer!=llGetOwner())
        {
            llResetScript();
        }
    }
}