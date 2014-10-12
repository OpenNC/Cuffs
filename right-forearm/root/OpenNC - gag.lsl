////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - gag                                        //
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
string submenu = "Gag";
string dbtoken = "Gag";
string CLCMD = "gag";
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
list drool = ["Drool"];
integer gDroolRate = 3;

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
    string Droolrate;
    if (gDroolRate == 0) Droolrate = "Stopped";
    else if (gDroolRate == 1) Droolrate = "Fastest";
    else if (gDroolRate == 2) Droolrate = "Fast";
    else if (gDroolRate == 3) Droolrate = "Medium";
    else if (gDroolRate == 4) Droolrate = "Slow";
    else if (gDroolRate == 5) Droolrate = "Slowest";
    string prompt = "\nGag control menu\n Lock = Shows the lock and if RLV enabled in main menu, it will RLV lock it.";
    prompt += "\nShow = will fit the Gag.";
    prompt += "\nDrool Rate = " + Droolrate;
    list mybuttons = hide + lock + drool;
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
                    SendCmd("*","Gag=1","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_Gag=1", "");
                    hide = ["Show"];
                    DoMenu(AV);
                }
                else if (message == "Show")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","Gag=0","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_Gag=0", "");
                    hide = ["Hide"];
                    DoMenu(AV);
                }
                else if (message == "Lock")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","gLock=on","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_gLock=on", "");
                    lock = ["Unlock"];
                    DoMenu(AV);
                }
                else if (message == "Unlock")
                {
                    // OpenNC: send hide to blindfold
                    SendCmd("*","gLock=off","");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_bLock=off", "");
                    lock = ["Lock"];
                    DoMenu(AV);
                }
                else if (message == "Drool")
                {
                    // OpenNC: send hide to blindfold
                    gDroolRate += 1;
                    if (gDroolRate >=6) gDroolRate = 0;
                    SendCmd("*","gDrool=" + (string)gDroolRate,"");
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, dbtoken +"_gDrool=" + (string)gDroolRate, "");
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
                if (sMsg== "gLock=on") lock = ["Unlock"];
                else if (sMsg == "gLock=off") lock = ["Lock"];
                else if (sMsg == "Gag=1") hide = ["Show"];
                else if (sMsg == "Gag=0") hide = ["Hide"];
                list menuparams1 = llParseString2List(sMsg, ["="], []);
                string token1 = llList2String(menuparams1, 0);
                string sMsg1 = llList2String(menuparams1, 1);
                if (token1 =="gDrool") gDroolRate = (integer)sMsg1;
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