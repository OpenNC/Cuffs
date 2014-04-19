////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                              OpenNC - _control                                 //
//                                 version 3.960                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
//      Suport for Arms, Legs, Wings, and Tail cuffs and restrictions             //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer RLV_CMD = 6000; //RLV command channel
integer RLV_REFRESH = 6001; //RLV plugins should reinstate their restrictions upon receiving this message.
integer    LM_CUFF_CMD        = -551001; // cuff command channel
integer    LM_CUFF_ANIM    = -551002; // cuff animation channel
integer LM_CUFF_CHAINTEXTURE = -551003; // used as channel for linked messages - sending the choosen texture to the cuff
integer g_nCmdChannel    = -190890; // command channel
integer g_nCuffChannel    = -190889; // cuff channel used for LG chains from the cuffs
integer g_nLockGuardChannel = -9119;
integer    g_nCmdHandle    = 0;  // command listen handler
integer    g_nCuffHandle    = 0; // cuff command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;  // offset to be used to make sure we do not interfere with other items using the same technique for
key        g_keyWearer        = ""; // key of the owner/wearer
integer g_nStdChannel    = 0; // standard chat channel
integer g_nStdHandle; // standard listen handler
//===================
//cuff prefixes
//prefixes for communication
//===================
list    g_lstExtPrefix    = [
    "occ",  //occ     opencollar collar command module, please make sure to change that for you items, the list of names following ids should only be used for cuffs!
    "chest",
    "skull",
    "lhand",
    "rhand",
    "lfoot",
    "rfoot",
    "spine",
    "mouth",
    "chin",
    "lear",
    "rear",
    "leye",
    "reye",
    "nose",
    "rhip",
    "rpec",
    "HUD Center 2",
    "HUD Top Right",
    "HUD Top",
    "HUD Top Left",
    "HUD Center",
    "HUD Bottom Left",
    "HUD Bottom",
    "HUD Bottom Right",
    "ruac", //ruac    right upper arm cuff
    "rlac", //rlac    right lower arm cuff
    "luac", //luac    left upper arm cuff
    "llac", //rlac    left lower arm cuff
    "rulc", //rulc    right upper leg cuff
    "rllc", //rllc    right lower leg cuff
    "lulc", //lulc    left upper leg cuff
    "lllc", //lllc    left lower leg cuff
    "lpec", //lpec    left pec (belt)
    "lhip", //lhip    left hip (tail)
    "lshoulder", //lshoulder   left shoulder (wing)
    "rshoulder", //rshoulder   right shoulder (wing)
    "ocbelt" //opencuffs belt
        ];
list    g_lstModTokens = ["rlac"]; // valid token for this module
integer CMD_UNKNOWN = -1; // unknown command - don't handle
integer CMD_CHAT  = 0; // chat cmd - check what should happen with it
integer CMD_EXTERNAL = 1; // external cmd - check what should happen with it
integer CMD_MODULE = 2; // cmd for this module
integer g_nCmdType = CMD_UNKNOWN;
// external command syntax
// sender prefix|receiver prefix|command1=value1~command2=value2|UUID to send under
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...
string  g_szReceiver = "";
string  g_szSender = "";
//_anim
string  g_szActAAnim = ""; // arm anim
string  g_szActLAnim = ""; // leg anim
string  g_szActWAnim = ""; // wing anim
string  g_szActTAnim = ""; // wing anim
integer g_nOverride = 0;
float   g_nOverrideTime = 0.25;
integer g_nInOverride = FALSE;
integer g_nLock = FALSE;
//_func
string  g_szModToken = "rlac"; // valid token for this module
//AOSWITCH
// Cleo: For Communication with AOs
integer g_nArmAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer g_nLegAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer g_nWingAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer g_nTailAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer g_nAOState = TRUE; // AO is on by default;
string  g_szStopCommand = "Stop"; // command to stop an animation
// variable for SUB AO communication
integer g_nAOChannel = -782690;
string  g_szAO_ON = "ZHAO_UNPAUSE";
string  g_szAO_OFF = "ZHAO_PAUSE";
// variable for staying in place
integer g_nStay = FALSE;
integer g_nStayMode = FALSE;
integer g_nSlowMode = FALSE;
// variable for staying in place
integer g_nRLVArms = FALSE;
integer g_nRLVLegs = FALSE;
integer g_nRLVWings = FALSE;
integer g_nRLVTail = FALSE;
integer g_nRLVMode = FALSE;
string  g_szWearerName;
// slowing down wearer
vector g_vBase_impulse = <0.5,0,0>;
integer g_nDuration = 5;
integer g_nStart_time;
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
//= parameters   : key keyID - the key to check for permission
//=
//= retun        : TRUE if permission is granted
//=
//= description  : checks if the key is allowed to send command to this modul
//=
//===============================================================================
integer IsAllowed( key keyID )
{
    integer nAllow    = FALSE;
    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;
    return nAllow;
}
//===============================================================================
//= parameters   : none
//=
//= retun        : none
//=
//= description  : get owner/wearer key and opens the listeners
//=
//===============================================================================
Init()
{
    g_keyWearer = llGetOwner();
    g_szWearerName=llKey2Name(g_keyWearer);
    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);// get the owner defined channel
    g_nCuffChannel = g_nCmdChannel+1;
    llListenRemove(g_nStdHandle);
    llListenRemove(g_nCmdHandle);
    llListenRemove(g_nCuffHandle);
    g_nStdHandle = llListen(g_nStdChannel, "", "", "");
    g_nCmdHandle = llListen(g_nCmdChannel, "", "", "");
    g_nCuffHandle = llListen(g_nCuffChannel, "", "", "");
    GetPermissions();
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :    string    command without prefixes if it has to be handled here
//=
//= description  :    checks if the message includes a valid ext. prefix
//=                    and if it's for this module
//=
//===============================================================================
string CheckCmd( key keyID, string szMsg )
{
    list lstParsed = llParseString2List( szMsg, [ "|" ], [] );
    string szCmd = szMsg;
    // first part should be sender token
    // second part the receiver token
    // third part = command
    if ( llGetListLength(lstParsed) > 2 )
    { // check the sender of the command occ,rwc,...
        g_szSender    = llList2String(lstParsed,0);
        integer nIdx         = llListFindList(g_lstExtPrefix, [g_szSender]);
        g_nCmdType        = CMD_UNKNOWN;
        if ( nIdx != -1 ) // a known external sender
        {
            g_nCmdType    = CMD_EXTERNAL;
            g_szReceiver = llList2String(lstParsed,1);// cap and store the receiver
            if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )// we are the receiver
            { // set cmd return to the rest of the command string
                szCmd = llList2String(lstParsed,2);
                g_nCmdType = CMD_MODULE;
            }
        }
    }
    lstParsed = [];
    return szCmd;
}
//_anim
//===============================================================================
//= parameters   : string szAnimInfo    part info & animation
//=                key keyID        key of the calling AV
//=
//= description  : Stops old animation if available
//=                and starts new on - if parameter not "Stop"
//=
//===============================================================================
DoAnim( string szAnimInfo, key keyID )
{
    string szInfo = llGetSubString(szAnimInfo, 0,1);
    string szAnim = llGetSubString(szAnimInfo, 2,-1);
    // works only if the animation is found in inventory
    if (llGetInventoryType(szAnim) == INVENTORY_ANIMATION || llToLower(szAnim) == "stop")
    {
        if (llGetPermissionsKey() != "")
        {
            if ( szInfo == "a:" ) // arm anim
            {
                _DoAnim(g_szActAAnim, szAnim, keyID);
                g_szActAAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActAAnim = szAnim;
                }
            }
            if ( szInfo == "l:" ) // leg anim
            {
                _DoAnim(g_szActLAnim, szAnim, keyID);
                g_szActLAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActLAnim = szAnim;
                }
            }
            if ( szInfo == "w:" ) // wing anim
            {
                _DoAnim(g_szActWAnim, szAnim, keyID);
                g_szActWAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActWAnim = szAnim;
                }
            }
            if ( szInfo == "t:" ) // tail anim
            {
                _DoAnim(g_szActTAnim, szAnim, keyID);
                g_szActTAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActTAnim = szAnim;
                }
            }
            if ( szInfo == "*:" ) // all anim
            {
                if ( llToLower(szAnim) == "stop" )
                {
                    _DoAnim(g_szActAAnim, szAnim, keyID);
                    _DoAnim(g_szActLAnim, szAnim, keyID);
                    _DoAnim(g_szActWAnim, szAnim, keyID);
                    _DoAnim(g_szActTAnim, szAnim, keyID);
                    g_szActAAnim = "";
                    g_szActLAnim = "";
                    g_szActWAnim = "";
                    g_szActTAnim = "";
                }
            }

        }
    }
}
//===============================================================================
//= parameters   : string szActAnim actual leg/arm anim
//=                string szAnim    new animation
//=                key keyID        key of the calling AV
//=
//= description  : Stops old animation if available
//=                and starts new on - if parameter not "Stop"
//=
//===============================================================================
_DoAnim(string szActAnim, string szAnim, key keyID )
{
            if ( szActAnim != "" )
            {
                llSetTimerEvent(0);
                g_nOverride = FALSE;
                llStopAnimation(szActAnim);
            }
            if ( llToLower(szAnim) != "stop" )
            {
                llStartAnimation(szAnim);
                g_nOverride = TRUE;
                llSetTimerEvent(g_nOverrideTime);
            }
}
//===============================================================================
//= description  : overrides the animations - called from timer and control
//===============================================================================
Override()
{
    if ( ! g_nInOverride )
    {
//        GetPermissions();//ng
        g_nInOverride = TRUE;

        if ( g_nOverride && g_szActAAnim != "" )
        {
            llStopAnimation(g_szActAAnim);
            llStartAnimation(g_szActAAnim);
        }

        if ( g_nOverride && g_szActLAnim != "" )
        {
            llStopAnimation(g_szActLAnim);
            llStartAnimation(g_szActLAnim);
        }
        
        if ( g_nOverride && g_szActWAnim != "" )
        {
            llStopAnimation(g_szActWAnim);
            llStartAnimation(g_szActWAnim);
        }
        if ( g_nOverride && g_szActTAnim != "" )
        {
            llStopAnimation(g_szActTAnim);
            llStartAnimation(g_szActTAnim);
        }
        g_nInOverride = FALSE;
    }
}
//===============================================================================
//= description  : permission request for animation & take controls
//===============================================================================
GetPermissions()
{
    if ( llGetAttached() )
        llRequestPermissions(llGetOwner(),PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS);
}
//_func
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
    llRegionSay(g_nCmdChannel + 1, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :
//=
//= description  :    devides the command string into single commands
//=                    delimiter = ~
//=                    single commands are redirected to ParseSingleCmd
//=
//===============================================================================
ParseCmdString( key keyID, string szMsg )
{
    list    lstParsed = llParseString2List( szMsg, [ "~" ], [] );
    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;
    for (i = 0; i < nCnt; i++ )
    {
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    }
    lstParsed = [];
}
//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   single command string
//=
//= retun        :
//=
//= description  :    devides the command string into command & parameter
//=                    delimiter is =
//=
//===============================================================================
ParseSingleCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "=" ], [] );
    string    szCmd    = llList2String(lstParsed,0);
    string    szValue    = llList2String(lstParsed,1);
    key       sztoucher = llList2String(lstParsed,2);
    if ( szCmd == "chain" )
    {
        if (( llGetListLength(lstParsed) == 4 ) || ( llGetListLength(lstParsed) == 7 ))
        {
            if ( llGetKey() != keyID )
                llMessageLinked( LINK_SET, LM_CUFF_CMD, szMsg, llGetKey() );
        }
    }
    else if (szCmd == "cmenu" )
    {
        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "cmenu", sztoucher);//send to auth
    }

    lstParsed = [];
}
//AOSWITCH
//===============================================================================
//= parameters   :    none
//=
//= retun        :    none
//=
//= description  :    Cleo: Sends commands to OC Sub Ao and LM comaptible AOs to disable them
//=
//===============================================================================
DisableAOs()
{ 
    llSay(-8888,((string)llGetOwner())+"bootoff");// send LM command for disabling AOs
    llSay(g_nAOChannel, g_szAO_OFF);//switch off OpenCollar Sub AO
}
//===============================================================================
//= parameters   :    none
//=
//= retun        :    none
//=
//= description  :    Cleo: Sends commands to LM comaptible AOs to enable them again
//=
//===============================================================================
EnableAOs()
{
    llSay(-8888,((string)llGetOwner())+"booton");// send LM command for enabling AOs
    llSay(g_nAOChannel, g_szAO_ON);//switch on OpenCollar Sub AO
}

StayPut()
{
    if (g_nStay) return;
    g_nStay = TRUE;
    llRequestPermissions(g_keyWearer, PERMISSION_TAKE_CONTROLS);
    llOwnerSay("You are bound, so your movement is restricted.");
}

UnStay()
{
    if (!g_nStay) return;
    g_nStay = FALSE;
    llReleaseControls();
    llOwnerSay("You are free to move again.");
}

RLVRestrictions(integer ShowMessages)
{
    if (g_nRLVMode)
    {
        if(g_nArmAnimRunning)
        {
            if (!g_nRLVArms)
            {
                if (ShowMessages) llOwnerSay("Your arms are bound, so you can do only limited things.");
                g_nRLVArms=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=n,rez=n,showinv=n,fartouch=n", "");
            }

        }
        else
        {
            if (g_nRLVArms)
            {
                if (ShowMessages) llOwnerSay("Your arms are free to touch things again.");

                g_nRLVArms=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=y,rez=y,showinv=y,fartouch=y", "");
            }
        }
        if(g_nLegAnimRunning)
        {
            if (!g_nRLVLegs)
            {
                if (ShowMessages) llOwnerSay("Your legs are bound, so you can only limited move.");

                g_nRLVLegs=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=n,tplm=n,tploc=n,tplure=n", "");
            }

        }
        else
        {
            if (g_nRLVLegs)
            {
                if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");

                g_nRLVLegs=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y,tplm=y,tploc=y,tplure=y", "");
            }
        }
        if(g_nWingAnimRunning)
        {
            if (!g_nRLVWings)
            {
                if (ShowMessages) llOwnerSay("Your Wings are bound, so you can only limited move.");

                g_nRLVWings=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "fly=n", "");
            }

        }
         else
        {
            if (g_nRLVWings)
            {
                if (ShowMessages) llOwnerSay("Your Wings are free, you can move normal again.");

                g_nRLVWings=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "fly=y", "");
            }
        }
        if(g_nTailAnimRunning)
        {
            if (!g_nRLVTail)
            {
//                if (ShowMessages) llOwnerSay("Your Tail is bound, so you can only limited move.");
                g_nRLVTail=TRUE;
//                llMessageLinked(LINK_THIS, RLV_CMD, "fly=n", "");
            }

        }
         else
        {
            if (g_nRLVTail)
            {
//                if (ShowMessages) llOwnerSay("Your Wings are free, you can move normal again.");
                g_nRLVTail=FALSE;
//                llMessageLinked(LINK_THIS, RLV_CMD, "fly=y", "");
            }
        }
    }
    else
    {
        if (g_nRLVArms)
        {
            if (ShowMessages) llOwnerSay("Your are free to touch things again.");
            llMessageLinked(LINK_THIS, RLV_CMD, "edit=y,rez=y,showinv=y,fartouch=y", "");
            g_nRLVArms=FALSE;
        }
        if (g_nRLVLegs)
        {
            llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y,tplm=y,tploc=y,tplure=y", "");
            g_nRLVLegs=FALSE;
            if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");
        }
        if (g_nRLVWings)
        {
            llMessageLinked(LINK_THIS, RLV_CMD, "fly=y", "");
            g_nRLVWings=FALSE;
            if (ShowMessages) llOwnerSay("Your Wings are free, you can move normal again.");
        }
        if (g_nRLVTail)
        {
//            llMessageLinked(LINK_THIS, RLV_CMD, "fly=y", "");
            g_nRLVTail=FALSE;
//            if (ShowMessages) llOwnerSay("Your Tail is free, you can move normal again.");
        }
    }
}


default
{
    state_entry()
    {
        Init();
        llListen(g_nLockGuardChannel,"","","");
    }
    
    attach(key attached)
    {
        if (attached != "")   // object has been attached
        {
            Init();
        }
    }

    control( key keyID, integer nHeld, integer nChange )
    {  // Is the user holding down left or right?
        if ( nHeld & (CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_FWD|CONTROL_BACK) )
        {
            Override();
        }
         if (g_nSlowMode)
        {
            if (nChange & (CONTROL_FWD | CONTROL_BACK)) g_nStart_time = llGetUnixTime();
            float wear_off = (g_nDuration + g_nStart_time - llGetUnixTime() + 0.0)/g_nDuration;
            if (wear_off < 0) wear_off = 0;
            vector impulse = wear_off * g_vBase_impulse;
            if (nHeld & CONTROL_FWD)
            {
                llApplyImpulse(impulse , TRUE);
            }
            else if (nHeld & CONTROL_BACK)
            {
                llApplyImpulse(-impulse , TRUE);
            }
        }
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
                string szCmd = llToLower(llStringTrim(szMsg, STRING_TRIM));
        if ( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "detach=n")
            {
            }
            else if ( szMsg == "reset")
            {
                llResetScript();
            }
            // set the receiver/module token of this module
            else if ( llGetSubString(szMsg,0,8)  == "settoken=" )
            {
                g_szModToken = llGetSubString(szMsg,9,-1);
            }
            else if (llGetSubString(szMsg,0,4) == "Lock=" )
            {
                SendCmd("*",szMsg,"");
            }
            else if (szMsg == "rlvon")
            {
                SendCmd("*","rlvon","");
            }
            else if (szMsg == "rlvoff")
            {
                SendCmd("*","rlvoff","");
            }
             else if (szMsg == "staymode=on")
            {
                g_nStayMode = TRUE;
                g_nSlowMode = FALSE;
                if (g_nLegAnimRunning)
                {
                    StayPut();
                }
            }
            else if (szMsg == "staymode=slow")
            {
                g_nStayMode = FALSE;
                g_nSlowMode = TRUE;
                if (g_nLegAnimRunning)
                {
                    StayPut();
                }
            }
            else if (szMsg == "staymode=off")
            {
                g_nStayMode = FALSE;
                if (g_nStay)
                {
                    UnStay();
                }
            }
            else if (szMsg == "rlvmode=on")
            {
                g_nRLVMode = TRUE;
                RLVRestrictions(TRUE);
            }
            else if (szMsg == "rlvmode=off")
            {
                g_nRLVMode = FALSE;
                RLVRestrictions(TRUE);
            }
            else
            {
                ParseCmdString(keyID, szCmd);
            }
        }
        else if( nNum == LM_CUFF_ANIM )
        {
            DoAnim(szMsg, keyID);
            // pasre the message
            list lCommands=llParseString2List(szMsg,[":"],[]);
            string szTarget=llList2String(lCommands,0); // Arms or Legs or Wings?
            string szAnim=llList2String(lCommands,1); // Stop or another anim
            if (szTarget=="a") // Command for the Arms
            {
                if (szAnim==g_szStopCommand) // Stop received
                {
                    g_nArmAnimRunning=FALSE;
                }
                else  // Normal anim received
                {
                    g_nArmAnimRunning=TRUE;
                }
            }

            if (szTarget=="l") // Command for the Legs
            {
                if (szAnim==g_szStopCommand) // Stop received
                {
                    g_nLegAnimRunning=FALSE;
                }
                else // Normal anim received
                {
                    g_nLegAnimRunning=TRUE;
                }
            }
            if (szTarget=="w") // Command for the Wings
            {
                if (szAnim==g_szStopCommand) // Stop received
                {
                    g_nWingAnimRunning=FALSE;
                }
                else // Normal anim received
                {
                    g_nWingAnimRunning=TRUE;
                }
            }
            if (szTarget=="t") // Command for the Tail
            {
                if (szAnim==g_szStopCommand) // Stop received
                {
                    g_nTailAnimRunning=FALSE;
                }
                else // Normal anim received
                {
                    g_nTailAnimRunning=TRUE;
                }
            }
            // now check if AOState has to be changed
            if (g_nAOState) // AO running atm
            {  // disable AO if an arm OR a leg OR a Wing or Tail anim runs
                if ((g_nArmAnimRunning==TRUE)||(g_nLegAnimRunning==TRUE)||(g_nWingAnimRunning==TRUE)||(g_nTailAnimRunning==TRUE))
                {
                    DisableAOs();
                    g_nAOState=FALSE;
                }
            }
            else // AO is in sleep
            { // enable AO if no arm AND no leg AND no Wing AND no Tail anim runs
                if ((g_nArmAnimRunning==FALSE)&&(g_nLegAnimRunning==FALSE)&&(g_nWingAnimRunning==FALSE)&&(g_nTailAnimRunning==FALSE))
                {
                    EnableAOs();
                    g_nAOState=TRUE;
                }
            }
            if (g_nStayMode&&(g_nLegAnimRunning==TRUE))
            {
                StayPut();
            }
            else
            {
                UnStay();
            }
            RLVRestrictions(TRUE);
        }
        else if( nNum == LM_CUFF_CHAINTEXTURE )
        {
            SendCmd("*",szMsg,"");
        }
        else if (nNum == RLV_REFRESH)
        {
            g_nRLVArms=FALSE;
            g_nRLVLegs=FALSE;
            g_nRLVWings=FALSE;
            g_nRLVTail=FALSE;
            RLVRestrictions(FALSE);
        }
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);
        if ( nChannel == g_nCmdChannel )// commands sent on cmd channel
        {
            if ( IsAllowed(keyID) )
            { // check if external or maybe for this module
                string szCmd = CheckCmd( keyID, szMsg );
                if ( g_nCmdType == CMD_MODULE )
                {
                    llMessageLinked(LINK_THIS, LM_CUFF_CMD, szCmd, llGetOwnerKey(keyID));
                }
            }
        }
        if ( nChannel == g_nCuffChannel )// commands sent on cuff channel, in thes case only lockguard
        {
            if (IsAllowed(keyID))
            {
                if (llGetSubString(szMsg,0,8)=="lockguard")
                {
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                }
            }
        }
        else if ( nChannel == g_nStdChannel )
        { // test for chat message
            if ( g_nCmdType == CMD_CHAT )
            {
                llMessageLinked(LINK_THIS, LM_CUFF_CMD, szMsg, llGetOwnerKey(keyID));
            }
        }
        else if ( nChannel == g_nLockGuardChannel )
        {
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,"");
        }
    }
    
    run_time_permissions(integer nParam)
    {
        if( nParam == (PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS))
        {
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
        //disable all controls but left mouse button (for stay cmd)
            if (g_nLegAnimRunning && g_nSlowMode) //slowdown only
            {
                llTakeControls(CONTROL_FWD|CONTROL_BACK, TRUE, FALSE);
            }
            if (g_nLegAnimRunning && g_nStayMode) // full stay
            {
                llTakeControls( CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON, FALSE, FALSE);
            }
        }
    }

    timer()
    {
        GetPermissions();
        if (g_szActAAnim != "" )
        {
            llStopAnimation(g_szActAAnim);
            llStartAnimation(g_szActAAnim);
        }

        if (g_szActLAnim != "" )
        {
            llStopAnimation(g_szActLAnim);
            llStartAnimation(g_szActLAnim);
        }
        
        if (g_szActWAnim != "" )
        {
            llStopAnimation(g_szActWAnim);
            llStartAnimation(g_szActWAnim);
        }
        if (g_szActTAnim != "" )
        {
            llStopAnimation(g_szActTAnim);
            llStartAnimation(g_szActTAnim);
        }
    }
    
    on_rez(integer rez_state) 
    {
        llResetScript(); //left in so it clears listens on rez
    }
}