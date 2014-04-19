////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - listener cuff                              //
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

integer g_iListenChan = 1;
integer g_iListenChan0 = TRUE;
string g_sPrefix = ".";
integer g_iListener1;
integer g_iListener2;
integer INTERFACE_CHANNEL;
integer COLLAR_CHANNEL;
integer SYNC = TRUE;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_COLLAR = 499;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer POPUP_HELP = 1001;
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
string g_sSafeWord = "RED";
//added for attachment auth
integer g_iInterfaceChannel = -12587429;
integer g_iListenHandleAtt;
integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
integer ATTACHMENT_FORWARD = 610;
key g_kWearer;
string g_sSeparator = "|";
string g_iAuth;
string UUID;
string g_sCmd;

//===============================================================================
//= parameters   :    key owner            key of the person to send the message to
//=                    integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
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

SetListeners()
{
    INTERFACE_CHANNEL = GetOwnerChannel(g_kWearer, 1111);
    COLLAR_CHANNEL = INTERFACE_CHANNEL++;
    llListenRemove(INTERFACE_CHANNEL);
    llListenRemove(COLLAR_CHANNEL);
    llListenRemove(g_iListener1);
    llListenRemove(g_iListener2);
    llListenRemove(g_iListenHandleAtt);
    if(g_iListenChan0 == TRUE)
    {
        g_iListener1 = llListen(0, "", "", "");
    }
    g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
    if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
    g_iListenHandleAtt = llListen(g_iInterfaceChannel, "", "", "");
    g_iListener2 = llListen(g_iListenChan, "", "", "");
    llListen(INTERFACE_CHANNEL, "", "", "");//Listen to external Objects here
    llListen(COLLAR_CHANNEL, "", "", "");//Listen to Our Collar here
}

string AutoPrefix()
{
    list sName = llParseString2List(llKey2Name(g_kWearer), [" "], []);
    return llToLower(llGetSubString(llList2String(sName, 0), 0, 0)) + llToLower(llGetSubString(llList2String(sName, 1), 0, 0));
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    //Ilse: blame/applaud Strife Onizuka for this godawfully ugly though apparently optimized function
    integer iLen = (~-(llStringLength(sFrom)));
    if(~iLen)
    {
        string  sBuffer = sSrc;
        integer iBufPos = -1;
        integer iToLen = (~-(llStringLength(sTo)));
        @loop;//instead of a while loop, saves 5 bytes (and run faster).
        integer iToPos = ~llSubStringIndex(sBuffer, sFrom);
        if(iToPos)
        {
            iBufPos -= iToPos;
            sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos, iBufPos + iLen), iBufPos, sTo);
            iBufPos += iToLen;
            sBuffer = llGetSubString(sSrc, (-~(iBufPos)), 0x8000);
            jump loop;
        }
    }
    return sSrc;
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) 
    {
    if (kID == g_kWearer) 
    {
        llOwnerSay(sMsg);
    } 
    else 
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) 
        {
            llOwnerSay(sMsg);
        }
    }
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        g_sPrefix = AutoPrefix();
        SetListeners();
    }

    listen(integer sChan, string sName, key kID, string sMsg)
    {
        // new object/HUD channel block
         if((kID == g_kWearer) && ((sMsg == g_sSafeWord)||(sMsg == "(("+g_sSafeWord+"))")))
        { // safeword can be the safeword or safeword said in OOC chat "((SAFEWORD))"
            llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", "");
            llOwnerSay("You used your safeword, your owner will be notified you did.");
        }
        if (sChan == INTERFACE_CHANNEL)//from external objects
        {
            list lParams = llParseString2List(sMsg, [":"], []);
            integer i = llGetListLength(lParams);
            key kTouch = (key)llList2String(lParams, 0);
            sMsg = llList2String(lParams, 1);
            if (kTouch)
            {
                string out = llDumpList2String([sMsg], "|");

                llMessageLinked(LINK_SET, COMMAND_NOAUTH, out, llGetOwnerKey(kID));//send to auth to check
            }
            else //this should never happen
            {
                Notify(kID, "Syntax Error! Request must be <uuid>:<command>", FALSE);
            }
        }
         else if (sChan == COLLAR_CHANNEL)//from our Collar
        {
            if (SYNC) //only do if collar sync is on (this needs writing)
            {
                string sMsg1 = "";
                string sMsg2 = "";
                string sMsg3 = "";
                string sMsg4 = "";
                string sMsg5 = "";
                string send_sMsg = "";
                string send_sMsg1 = "";
                list lParams1 = llParseString2List(sMsg, [":"], []);
                integer j = llGetListLength(lParams1);
                key kTouch1 = llList2Key(lParams1, 0);
                sMsg1 = llList2String(lParams1, 1);
                list lParams2 = llParseString2List(sMsg1, ["="], []);
                integer k = llGetListLength(lParams2);
                sMsg2 = llList2String(lParams2, 0);
                sMsg3 = llList2String(lParams2, 1);
                if ((sMsg2 == "auth_owner") || (sMsg2 == "auth_secowners") || (sMsg2 == "auth_blacklist"))
                {//if any of these we need to reformat it and send it to auth.
                    integer start = 0;
                    list lParams3 = llParseString2List(sMsg3, [","], []);
                    integer l = llGetListLength(lParams3);
                    for (start = 0; start < l; start ++)
                    {
                        sMsg4 = llList2String(lParams3, start);
                        send_sMsg = send_sMsg + "," + sMsg4 +",";
                    }
                    send_sMsg1 = sMsg2 + "=" + send_sMsg;
                 llMessageLinked(LINK_SET, COMMAND_NOAUTH, send_sMsg1, llGetOwnerKey(kID));//send to auth
                }
                else if ((sMsg2 =="setgroup") || (sMsg2 =="unsetgroup") || (sMsg2 =="setopenaccess") || (sMsg2 =="unsetopenaccess"))
                { //if any of these just pass to NOAUTH to check who is sending it
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg2, llGetOwnerKey(kID));
                }
                else if (sMsg2 =="cmenu")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg2, llGetOwnerKey(kTouch1));
                }
                else if (sMsg2 =="runaway")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg2, llGetOwnerKey(kTouch1));
                }
                else if ((sMsg1 =="rlvon") || (sMsg1 =="rlvoff"))// lets send RLV on/off
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg1, llGetOwnerKey(kTouch1));
                    if (sMsg1 == "rlvoff")  llOwnerSay("RLV in your cuffs has been turned off from your Collar.");
                }
                else if ((sMsg1 =="show") || (sMsg1 =="hide"))// lets send apperance show/hide
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg1, llGetOwnerKey(kID));
                } 
                list lParams3 = llParseString2List(sMsg1, ["_"], []);
                sMsg2 = llList2String(lParams3, 0);
                if ((sMsg2 == "color") || (sMsg2 == "texture"))
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH,sMsg1, llGetOwnerKey(kID));
                }        
                if (kTouch1)
                {
                    string out = llDumpList2String([sMsg], "|");
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, out, llGetOwnerKey(kID));//send to auth
                }

                else//this should never happen
                {

                }
            }
        }
        else if (sChan == g_iInterfaceChannel)
        {
            //do nothing if wearer isnt owner of the object
            if (llGetOwnerKey(kID) != g_kWearer) return;
            integer iIndex = llSubStringIndex(sMsg, g_sSeparator);
            g_iAuth = llGetSubString(sMsg, 0, iIndex - 1);
            if (g_iAuth == "0") //auth request
            {
                g_sCmd = llGetSubString(sMsg, iIndex + 1, -1);
                iIndex = llSubStringIndex(g_sCmd, g_sSeparator);
                UUID = llGetSubString(g_sCmd, iIndex + 1, llStringLength(sMsg) - 40);
    //just send ATTACHMENT_REQUEST and ID to auth, as no script IN the cuffs needs the command anyway
                llMessageLinked(LINK_SET, ATTACHMENT_REQUEST, "", (key)UUID);
            }
            else if (g_iAuth == (string)COMMAND_COLLAR) //command from attachment to AO
            {
                llWhisper(g_iInterfaceChannel, sMsg);
            }
            else
            {
                // we received a unkown command, so we just forward it via LM into the cuffs
                llMessageLinked(LINK_SET, ATTACHMENT_FORWARD, sMsg, kID);
            }
        }
        else
        { //check for our prefix, or *
            if (StartsWith(sMsg, g_sPrefix))
            { //trim
                sMsg = llGetSubString(sMsg, llStringLength(g_sPrefix), -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            else if (llGetSubString(sMsg, 0, 0) == "*")
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            // added # as prefix for all subs around BUT yourself
            else if ((llGetSubString(sMsg, 0, 0) == "#") && (kID != g_kWearer))
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "settings")// answer for settings command
            {
                Notify(kID,"prefix: " + g_sPrefix, FALSE);
                Notify(kID,"channel: " + (string)g_iListenChan, FALSE);
            }
            else if (sStr == "ping")
            {// ping from an object, we answer to it on the object channel
                llSay(GetOwnerChannel(kID,1111),(string)g_kWearer+":pong");
            }
            else if (iNum == COMMAND_OWNER)//handle changing prefix and channel from owner
            {
                if (sCommand == "prefix")
                {
                    string sNewPrefix = llList2String(lParams, 1);
                    if (sNewPrefix == "auto")
                    {
                        g_sPrefix = AutoPrefix();
                    }
                    else if (sNewPrefix != "")
                    {
                        g_sPrefix = sNewPrefix;
                    }
                    SetListeners();
                    Notify(kID, "\n" + llKey2Name(g_kWearer) + "'s prefix is '" + g_sPrefix + "'.\nTouch the cuffs or say '" + g_sPrefix + "cmenu' for the main menu.\nSay '" + g_sPrefix + "help' for a list of chat commands.", FALSE);
                }
                else if (sCommand == "channel")
                {
                    integer iNewChan = (integer)llList2String(lParams, 1);
                    if (iNewChan > 0)
                    {
                        g_iListenChan =  iNewChan;
                        SetListeners();
                        Notify(kID, "Now listening on channel " + (string)g_iListenChan + ".", FALSE);
                    }
                    else if (iNewChan == 0)
                    {
                        g_iListenChan0 = TRUE;
                        SetListeners();
                        Notify(kID, "You enabled the public channel listener.\nTo disable it use -1 as channel command.", FALSE);
                    }
                    else if (iNewChan == -1)
                    {
                        g_iListenChan0 = FALSE;
                        SetListeners();
                        Notify(kID, "You disabled the public channel listener.\nTo enable it use 0 as channel command, remember you have to do this on your channel /" +(string)g_iListenChan, FALSE);
                    }
                    else
                    {  //they left the param blank
                        Notify(kID, "Error: 'channel' must be given a number.", FALSE);
                    }
                }
            }
            if (kID == g_kWearer)
            {
                if (sCommand == "safeword")
                {   // new for safeword
                    if(llStringTrim(sValue, STRING_TRIM) != "")
                    {
                        g_sSafeWord = llList2String(lParams, 1);
                        llOwnerSay("You set a new safeword: " + g_sSafeWord + ".");
                    }
                    else
                    {
                        llOwnerSay("Your safeword is: " + g_sSafeWord + ".");
                    }
                }
                else if (sStr == g_sSafeWord)
                { //safeword used with prefix
                    llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", "");
                    llOwnerSay("You used your safeword, your owner will be notified you did.");
                }
            }
        }

        else if (iNum == POPUP_HELP)
        { //replace _PREFIX_ with prefix, and _CHANNEL_ with (string) channel
            sStr = StringReplace(sStr, "_PREFIX_", g_sPrefix);
            sStr = StringReplace(sStr, "_CHANNEL_", (string)g_iListenChan);
            Notify(kID, sStr, FALSE);
        }
        else if (iNum == ATTACHMENT_RESPONSE)
        {
            //here the response from auth has to be:
            // llMessageLinked(LINK_SET, ATTACHMENT_RESPONSE, "auth", UUID);
            //where "auth" has to be (string)COMMAND_XY
            //reason for this is: i dont want to have all other scripts recieve a COMMAND+xy and check further for the command
            llWhisper(g_iInterfaceChannel, "RequestReply|" + sStr + g_sSeparator + g_sCmd);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}