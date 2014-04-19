////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenNC - dialog cuff                              //
//                                 version 3.960                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

//an adaptation of Schmobag Hogfather's SchmoDialog script

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer FIND_AGENT = -9005;
integer iPagesize = 12;
string MORE = "►";
string PREV = "◄";
string UPMENU = "BACK"; // string to identify the UPMENU button in the utility lButtons
string BLANK = " ";
integer g_iTimeOut = 300;
integer g_iReapeat = 5;//how often the timer will go off, in seconds
list g_lMenus;//11-strided list in form listenChan, dialogid, listener, starttime, recipient, prompt, list buttons, utility buttons, currentpage, button digits, auth level
//where "list buttons" means the big list of choices presented to the user
//and "page buttons" means utility buttons that will appear on every page, such as one saying "go up one level"
//and "currentpage" is an integer meaning which page of the menu the user is currently viewing
list g_lRemoteMenus;
integer g_iStrideLength = 12;
// List of user keys who opt-out of chat-spammage, ie chose "off"
list MRSBUN = []; // blatant monty python reference - list of those who do not like spam
string SPAMSWITCH = "verbose"; // lowercase chat-command token

key g_kWearer;
string g_sScript;
string g_sGetAviScript = "getavi_";
string Key2Name(key kId)
{
    string sOut = llGetDisplayName(kId);
    if (sOut) return sOut;
    else return llKey2Name(kId);
}

string Integer2String(integer iNum, integer iDigits)
{
    string sOut = "";
    integer i = 0;
    for (; i <iDigits; i++)
    {
        sOut = (string) (iNum%10) + sOut;
        iNum /= 10;
    }
    return sOut;
}

integer GetStringBytes(string sStr)
{
    sStr = llEscapeURL(sStr);
    integer l = llStringLength(sStr);
    list lAtoms = llParseStringKeepNulls(sStr, ["%"], []);
    return l - 2 * llGetListLength(lAtoms) + 2;
}

string TruncateString(string sStr, integer iBytes)
{
    sStr = llEscapeURL(sStr);
    integer j = 0;
    string sOut;
    integer l = llStringLength(sStr);
    for (; j < l; j++)
    {
        string c = llGetSubString(sStr, j, j);
        if (c == "%")
        {
            if (iBytes >= 2)
            {
                sOut += llGetSubString(sStr, j, j+2);
                j += 2;
                iBytes -= 2;
            }
        }
        else if (iBytes >= 1)
        {
            sOut += c;
            iBytes --;
        }
    }
    return llUnescapeURL(sOut);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else
    {
        llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

integer ButtonDigits(list lIn)
{// checks if any of the times is over 20 characters and deduces how many digits are needed
    integer m=llGetListLength(lIn);
    integer iDigits;
    if ( m < 10 ) iDigits = 1;
    else if (m < 100) iDigits = 2;
    else if (m < 1000) iDigits = 3; // more than 100 is unlikely, considering the size of a LM
    integer i;
    for (i=0;i<m;i++) if (GetStringBytes(llList2String(lIn,i))>18) return iDigits;
    return 0; // if no button label is too long, then no need for any digit
}

integer RandomUniqueChannel()
{
    integer iOut = llRound(llFrand(10000000)) + 100000;
    if (~llListFindList(g_lMenus, [iOut]))
    {
        iOut = RandomUniqueChannel();
    }
    return iOut;
}

Dialog(key kRecipient, string sPrompt, list lMenuItems, list lUtilityButtons, integer iPage, key kID, integer iWithNums, integer iAuth,string extraInfo)
{//string sThisPrompt = " (Timeout in "+ (string)g_iTimeOut +" seconds.)";
    string sThisPrompt;
    list lButtons;
    list lCurrentItems;
    integer iNumitems = llGetListLength(lMenuItems);
    integer iStart;
    integer iMyPageSize = iPagesize - llGetListLength(lUtilityButtons);
    if (iNumitems > iMyPageSize)//slice the menuitems by page
    {
        iMyPageSize=iMyPageSize-2;//we'll use two slots for the MORE and PREV button, so shrink the page accordingly
        iStart = iPage * iMyPageSize;
        //multi page menu
        sThisPrompt = sThisPrompt + " Page "+(string)(iPage+1)+"/"+(string)(((iNumitems-1)/iMyPageSize)+1);
    }
    else iStart = 0;
    integer iEnd = iStart + iMyPageSize - 1;
    if (iEnd >= iNumitems) iEnd = iNumitems - 1;
    if (iWithNums) { // put numbers in front of buttons: "00 Button1", "01 Button2", ...
        integer iCur; for (iCur = iStart; iCur <= iEnd; iCur++) {
            string sButton = llList2String(lMenuItems, iCur);
            if ((key)sButton) sButton = Key2Name((key)sButton);
            sButton = Integer2String(iCur, iWithNums) + " " + sButton;
            sButton = TruncateString(sButton, 24);
            lButtons += [sButton];
        }
    }
    else if (iNumitems > iMyPageSize) lButtons = llList2List(lMenuItems, iStart, iEnd);
    else lButtons = lMenuItems;
    integer iPromptlen=GetStringBytes(sPrompt);// check promt lenghtes
    if (iPromptlen>511)
    {
        Notify(kRecipient,"The dialog prompt message is longer than 512 characters. It will be truncated to 512 characters.",TRUE);
        sPrompt=TruncateString(sPrompt,510);
        sThisPrompt = sPrompt;
    }
    else if (iPromptlen + GetStringBytes(sThisPrompt)< 512)
    {
        sThisPrompt= sPrompt + sThisPrompt;
    }
    else
    {
        sThisPrompt= sPrompt;
    }
    integer iChan = RandomUniqueChannel();
    integer iListener = llListen(iChan, "", kRecipient, "");
    llSetTimerEvent(g_iReapeat);
    if (iNumitems > iMyPageSize)
    {
        llDialog(kRecipient, sThisPrompt, PrettyButtons(lButtons, lUtilityButtons,[PREV,MORE]), iChan);
    }
    else
    {
        llDialog(kRecipient, sThisPrompt, PrettyButtons(lButtons, lUtilityButtons,[]), iChan);
    }
    integer ts = llGetUnixTime() + g_iTimeOut;
    g_lMenus += [iChan, kID, iListener, ts, kRecipient, sPrompt, llDumpList2String(lMenuItems, "|"), llDumpList2String(lUtilityButtons, "|"), iPage, iWithNums, iAuth,extraInfo];
}

list PrettyButtons(list lOptions, list lUtilityButtons, list iPagebuttons)
{//returns a list formatted to that "options" will start in the top left of a dialog, and "utilitybuttons" will start in the bottom right
    list lSpacers;
    list lCombined = lOptions + lUtilityButtons + iPagebuttons;
    while (llGetListLength(lCombined) % 3 != 0 && llGetListLength(lCombined) < 12)
    {
        lSpacers += [BLANK];
        lCombined = lOptions + lSpacers + lUtilityButtons + iPagebuttons;
    }
    integer u = llListFindList(lCombined, [UPMENU]);// check if a UPBUTTON is present and remove it for the moment
    if (u != -1)
    {
        lCombined = llDeleteSubList(lCombined, u, u);
    }
    list lOut = llList2List(lCombined, 9, 11);
    lOut += llList2List(lCombined, 6, 8);
    lOut += llList2List(lCombined, 3, 5);
    lOut += llList2List(lCombined, 0, 2);
    if (u != -1)
    {//make sure we move UPMENU to the lower right corner
        lOut = llListInsertList(lOut, [UPMENU], 2);
    }
    return lOut;
}

RemoveMenuStride(integer iIndex)       //fixme:  duplicates entire global lMenu list
{
    //tell this function the menu you wish to remove, identified by list index
    //it will close the listener, remove the menu's entry from the list, and return the new list
    //should be called in the listen event, and on menu timeout
    integer iListener = llList2Integer(g_lMenus, iIndex + 2);
    llListenRemove(iListener);
    g_lMenus=llDeleteSubList(g_lMenus, iIndex, iIndex + g_iStrideLength - 1);
}

CleanList()
{
    //loop through menus and remove any whose timeouts are in the past
    //start at end of list and loop down so that indices don't get messed up as we remove items
    integer iLength = llGetListLength(g_lMenus);
    integer n;
    integer iNow = llGetUnixTime();
    for (n = iLength - g_iStrideLength; n >= 0; n -= g_iStrideLength)
    {
        integer iDieTime = llList2Integer(g_lMenus, n + 3);
        if (iNow > iDieTime)
        {
            key kID = llList2Key(g_lMenus, n + 1);
            llMessageLinked(LINK_SET, DIALOG_TIMEOUT, "", kID);
            RemoveMenuStride(n);
        }
    }
}

ClearUser(key kRCPT)
{
    //find any strides belonging to user and remove them
    integer iIndex = llListFindList(g_lMenus, [kRCPT]);
    while (~iIndex)
    {
        RemoveMenuStride(iIndex -4);
        iIndex = llListFindList(g_lMenus, [kRCPT]);
    }
}

integer InSim(key id)
{
    return llKey2Name(id) != "";
}

integer UserCommand(integer iNum, string sStr, key kID)
{
    if (iNum < COMMAND_OWNER || iNum > COMMAND_WEARER) return FALSE;
    if (iNum == COMMAND_GROUP) return FALSE;
    list lParams = llParseString2List(llToLower(sStr), ["="], []);
    string sToken = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    if (sToken == SPAMSWITCH) // add/rem user to verbose=off list
    {
        integer i = llListFindList(MRSBUN, [kID]);
        if (sValue == "off")
        {
            if (~i) return TRUE; // already in list
            MRSBUN += [kID];
            Notify(kID, "Verbose Feature activated for you.", FALSE);
        }
        else if (~i)
        {
            MRSBUN = llDeleteSubList(MRSBUN, i, i);
            Notify(kID, "Verbose Feature de-activated for you.", FALSE);
        }
        else return TRUE; // not in list to start with
        if (!llGetListLength(MRSBUN)) llMessageLinked(LINK_THIS, LM_SETTING_DELETE, g_sScript + SPAMSWITCH, "");
        else llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sScript + SPAMSWITCH + "=" + llList2CSV(MRSBUN), "");
        return TRUE;
    }
    return FALSE;
}

default
{
    state_entry()
    {
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer=llGetOwner();
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
    if (iNum == FIND_AGENT) 
        {
            list lParams = llParseStringKeepNulls(sStr, ["|"], []);
            if (llList2String(lParams, 0) == g_sGetAviScript)
            {
                string REQ = llList2String(lParams, 1);
                key kRCPT = llGetOwnerKey((key)llList2String(lParams, 2));
                integer iAuth = (integer)llList2String(lParams, 3);
                string TYPE = llList2String(lParams, 4);
                string find = llList2String(lParams, 5);
                if (find == " ") find = "";
                list excl = llParseString2List(llList2String(lParams, 6), [","], []);
                list AVIS = [];
                list agentList = llGetAgentList(AGENT_LIST_REGION, []);
                integer i = llGetListLength(agentList);
                while(i--)
                {
                    key avId=llList2Key(agentList, i);
                    string name = llKey2Name(avId);
                    if (llSubStringIndex(llToLower(name), llToLower(find)) != -1)
                    { //if this name contains find string
                        if (! ~llListFindList(excl,[(string)avId]))
                        { //if this key is not in the excludelist
                            AVIS += avId;
                        }
                    }
                }
                i = llGetListLength(AVIS);
                if (!i)
                {
                     string findNotify;
                    if (find != "") findNotify = "starting with \"" + find + "\" ";
                    llInstantMessage(kRCPT, "Could not find any avatars "+ findNotify + "in this region.");
                } 
                else if (i == 1 && llList2Key(AVIS, 0) == kRCPT) 
                {
                    integer iDigits = ButtonDigits(["Yes", "No"]);
                    ClearUser(kRCPT);
                    Dialog(kRCPT, "\n\nYou are the only one in this region. Add yourself?", ["Yes", "No"], [UPMENU], 0, kID, iDigits, iAuth, "getavi_|"+REQ+"|"+TYPE);
                } 
                else 
                {
                    integer iDigits = ButtonDigits(AVIS);
                    ClearUser(kRCPT);
                    Dialog(kRCPT, "\n\nChoose the person you like to add.", AVIS, [UPMENU], 0, kID, iDigits, iAuth, "getavi_|"+REQ+"|"+TYPE);
                }
            }
            else 
            {
            }
        } 
        else if (iNum == DIALOG)
        {//give a dialog with the options on the button labels
            //str will be pipe-delimited list with rcpt|prompt|page|backtick-delimited-list-buttons|backtick-delimited-utility-buttons|auth
            list lParams = llParseStringKeepNulls(sStr, ["|"], []);
            key kRCPT = llGetOwnerKey((key)llList2String(lParams, 0));
            integer iIndex = llListFindList(g_lRemoteMenus, [kRCPT]);
            if (~iIndex)
            {
                if (!InSim(kRCPT))
                {
                    llHTTPRequest(llList2String(g_lRemoteMenus, iIndex+1), [HTTP_METHOD, "POST"], sStr+"|"+(string)kID);
                    return;
                }
                else
                {
                    g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [], iIndex, iIndex+1);
                }
            }
            string sPrompt = llList2String(lParams, 1);
            integer iPage = (integer)llList2String(lParams, 2);
            // SA: why should we keep nulls? Discarding them now saves us the use of SanitizeButtons()
            list lButtons = llParseString2List(llList2String(lParams, 3), ["`"], []);
            integer iDigits;
            if (!~llListFindList(MRSBUN, [kRCPT])) iDigits = ButtonDigits(lButtons);
            list ubuttons = llParseString2List(llList2String(lParams, 4), ["`"], []);
            integer iAuth = COMMAND_NOAUTH;
            if (llGetListLength(lParams)>=6) iAuth = llList2Integer(lParams, 5);
            //first clean out any strides already in place for that user. prevents having lots of listens open if someone uses the menu several times while sat
            ClearUser(kRCPT);
            //now give the dialog and save the new stride
            Dialog(kRCPT, sPrompt, lButtons, ubuttons, iPage, kID, iDigits, iAuth,"");
            if (iDigits)
            {
                integer iLength = GetStringBytes(sPrompt);
                string sOut = sPrompt;
                integer iNb = llGetListLength(lButtons);
                integer iCount;
                string sLine;
                for (iCount = 0; iCount < iNb; iCount++)
                {
                    string sButton = llList2String(lButtons, iCount);
                    if ((key)sButton) sButton = Key2Name((key)sButton);
                    sLine = "\n"+Integer2String(iCount, iDigits) + " " + sButton;
                    iLength += GetStringBytes(sLine);
                    if (iLength >= 1024)
                    {
                        Notify(kRCPT, sOut, FALSE);
                        iLength = 0;
                        sOut = "";
                    }
                    sOut += sLine;
                }
                Notify(kRCPT, sOut, FALSE);
            }
        }
        else if (llGetSubString(sStr, 0, 10) == "remotemenu:")
        {
            if (iNum == COMMAND_OWNER || iNum == COMMAND_SECOWNER)
            {
                string sCmd = llGetSubString(sStr, 11, -1);
                if (llGetSubString(sCmd, 0, 3) == "url:")
                {
                    integer iIndex = llListFindList(g_lRemoteMenus, [kID]);
                    if (~iIndex)
                    {
                        g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [kID, llGetSubString(sCmd, 4, -1)], iIndex, iIndex+1);
                    }
                    else
                    {
                        g_lRemoteMenus += [kID, llGetSubString(sCmd, 4, -1)];
                    }
                    llMessageLinked(LINK_SET, iNum, "menu", kID);
                }
                else if (llGetSubString(sCmd, 0, 2) == "off")
                {
                    integer iIndex = llListFindList(g_lRemoteMenus, [kID]);
                    if (~iIndex)
                    {
                        g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [], iIndex, iIndex+1);
                    }
                }
                else if (llGetSubString(sCmd, 0, 8) == "response:")
                {
                    list lParams = llParseString2List(llGetSubString(sCmd, 9, -1), ["|"], []);
                    llMessageLinked(LINK_SET, DIALOG_RESPONSE, llList2String(lParams, 0) + "|" + llList2String(lParams, 1) + "|" + llList2String(lParams, 2), llList2String(lParams, 3));
                }
                else if (llGetSubString(sCmd, 0, 7) == "timeout:")
                {
                    llMessageLinked(LINK_SET, DIALOG_TIMEOUT, "", llGetSubString(sCmd, 8, -1));
                }
            }
        }
        else if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(llToLower(sStr), ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sScript + SPAMSWITCH) MRSBUN = llParseString2List(sValue, [","], []);
        }
    }
    
    listen(integer iChan, string sName, key kID, string sMessage)
    {
        integer iMenuIndex = llListFindList(g_lMenus, [iChan]);
        if (~iMenuIndex)
        {
            key kMenuID = llList2Key(g_lMenus, iMenuIndex + 1);
            key kAv = llList2Key(g_lMenus, iMenuIndex + 4);
            string sPrompt = llList2String(g_lMenus, iMenuIndex + 5);
            // SA: null strings should not be kept for dialog buttons
            list items = llParseString2List(llList2String(g_lMenus, iMenuIndex + 6), ["|"], []);
            list ubuttons = llParseString2List(llList2String(g_lMenus, iMenuIndex + 7), ["|"], []);
            integer iPage = llList2Integer(g_lMenus, iMenuIndex + 8);
            integer iDigits = llList2Integer(g_lMenus, iMenuIndex + 9);
            integer iAuth = llList2Integer(g_lMenus, iMenuIndex + 10);
            string sExtraInfo = llList2String(g_lMenus, iMenuIndex + 11);
            RemoveMenuStride(iMenuIndex);
            if (sMessage == MORE)
            { //increase the page num and give new menu
                iPage++;
                integer thisiPagesize = iPagesize - llGetListLength(ubuttons) - 2;
                if (iPage * thisiPagesize >= llGetListLength(items))
                {
                    iPage = 0;
                }
                Dialog(kID, sPrompt, items, ubuttons, iPage, kMenuID, iDigits, iAuth,sExtraInfo);
            }
            else if (sMessage == PREV)
            { //increase the page num and give new menu
                iPage--;
                if (iPage < 0)
                {
                    integer thisiPagesize = iPagesize - llGetListLength(ubuttons) - 2;
                    iPage = (llGetListLength(items)-1)/thisiPagesize;
                }
                Dialog(kID, sPrompt, items, ubuttons, iPage, kMenuID, iDigits, iAuth, sExtraInfo);
            }
            else if (sMessage == BLANK)
            {//give the same menu back
                Dialog(kID, sPrompt, items, ubuttons, iPage, kMenuID, iDigits, iAuth, sExtraInfo);
            }
            else
            {
                string sAnswer;
                integer iIndex = llListFindList(ubuttons, [sMessage]);
                if (iDigits && !~iIndex)
                {
                    integer iBIndex = (integer) llGetSubString(sMessage, 0, iDigits);
                    sAnswer = llList2String(items, iBIndex);
                }
                else sAnswer = sMessage;
                if (llSubStringIndex(sExtraInfo,g_sGetAviScript+"|")==0)
                {
                    list lExtraInfo=llParseString2List(sExtraInfo,["|"],[]); //unpack info for avi dialog
                    string REQ=llList2String(lExtraInfo,1);
                    string TYPE=llList2String(lExtraInfo,2);
                    if (sMessage==UPMENU)
                    {
                        llMessageLinked(LINK_SET,iAuth,"access",kAv);
                    } 
                    else if (sMessage == "Yes") 
                    {
                        llMessageLinked(LINK_THIS, FIND_AGENT, REQ+"|"+g_sGetAviScript+"|"+(string)kAv+"|"+(string)iAuth+"|"+TYPE+"|"+(string)g_kWearer, kMenuID);
                    } 
                    else if (sMessage == "No") 
                    {//no action
                    } 
                    else 
                    {
                        llMessageLinked(LINK_THIS, FIND_AGENT, REQ+"|"+g_sGetAviScript+"|"+(string)kAv+"|"+(string)iAuth+"|"+TYPE+"|"+sAnswer, kMenuID);
                    }
                }

                llMessageLinked(LINK_SET, DIALOG_RESPONSE, (string)kAv + "|" + sAnswer + "|" + (string)iPage + "|" + (string)iAuth, kMenuID);
            }
        }
    }
    
    timer()
    {
        CleanList();
        if (!llGetListLength(g_lMenus))
        {//if list is empty after that, then stop timer
            llSetTimerEvent(0.0);
        }
    }
}