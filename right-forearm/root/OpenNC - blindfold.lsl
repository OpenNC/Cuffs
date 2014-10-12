////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - Blindfold                                  //
//                            version 3.980                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////
string parentmenu = "Apps";
string submenu = "Blindfold";
string dbtoken = "Blindfold";
string CLCMD = "blindfold";
key g_keyDialogID;
key g_keyWearer;
//Message Map
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer SENDCMD = 551;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer LM_CUFF_CMD = -551001;// used as channel for linkemessages - sending commands

string UPMENU = "BACK";
list lock = ["Unlock"];
list hide = ["Show"];
list blackout = ["Blackout"];

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

SendCmd( string szSendTo, string szCmd, key keyID )
{
    llMessageLinked( LINK_SET, SENDCMD, "rlac" + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID, keyID);
}

DoMenu(key id)
{
    string prompt = "\nBlindfold control menu\nLock = Shows the lock and if RLV enabled in main menu, it will RLV lock it.";
    prompt += "\nShow/Hide = will fit/hide the Blindfold, \nBlackout will Blackout the wearers screen using RLV";
    list mybuttons = hide + lock + blackout;
    prompt += "\n\nPick an option.";
    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}

default
{
    state_entry()
    {
        g_keyWearer = llGetOwner();
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, "");
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, dbtoken, "");//lets make sure we get our
    }

    link_message(integer sender, integer nNum, string str, key id)
    { //owner, secowner, group, and wearer may currently change colors
        if (str == "reset" && (nNum == COMMAND_OWNER || nNum == COMMAND_WEARER)) //clear saved settings
            llResetScript();
        else if (str  == "menu " + submenu || str == CLCMD)
        {
            DoMenu(id);
        }
        else if (nNum == MENUNAME_REQUEST)
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        else if ( nNum == LM_CUFF_CMD )
        {
            string szToken = llGetSubString(str, 0,1);
            if ( str == "reset")
                llResetScript();
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
                    llMessageLinked(LINK_THIS, iAuth, "menu "+ parentmenu, AV);//NEW command structer
                else if (message == "Hide")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","Blindfold=1","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_Blindfold=1", "");
                    hide = ["Show"];
                    DoMenu(AV);
                }
                else if (message == "Show")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","Blindfold=0","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_Blindfold=0", "");
                    hide = ["Hide"];
                    DoMenu(AV);
                }
                else if (message == "Lock")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","bLock=on","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_bLock=on", "");
                    lock = ["Unlock"];
                    DoMenu(AV);
                }
                else if (message == "Unlock")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","bLock=off","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_bLock=off", "");
                    lock = ["Lock"];
                    DoMenu(AV);
                }
                else if (message == "Blackout")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","blackout=on","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_blackout=on", "");
                    blackout = ["View"];
                    DoMenu(AV);
                }
                else if (message == "View")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","blackout=off","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_blackout=off", "");
                    blackout = ["Blackout"];
                    DoMenu(AV);
                }
            }
        }
        else if (nNum == LM_SETTING_RESPONSE)
        {
            list menuparams = llParseString2List(str, ["_"], []);
            string token = llList2String(menuparams, 0);
            string sMsg = llList2String(menuparams, 1);
            if(token == dbtoken)
            {
                SendCmd("*",sMsg,"");
                if (sMsg== "bLock=on") lock = ["Unlock"];
                else if (sMsg == "bLock=off") lock = ["Lock"];
                else if (sMsg == "Blindfold=1") hide = ["Show"];
                else if (sMsg == "Blindfold=0") hide = ["Hide"];
                else if (sMsg == "blackout=on") blackout = ["View"];
                else if (sMsg == "blackout=off") blackout = ["Blackout"];
            }
        }
        else if (str == CLCMD)
            DoMenu(id);
    }

    on_rez(integer param)
    {
        if (g_keyWearer!=llGetOwner())
            llResetScript();
    }
}