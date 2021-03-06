import XMonad hiding ((|||))
import XMonad.Actions.CycleRecentWS
import XMonad.Actions.PerLayoutKeys
import XMonad.Actions.UpdatePointer
import XMonad.Actions.WindowNavigation
import XMonad.Config.Desktop
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.FadeInactive
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.Accordion
import XMonad.Layout.Combo
import XMonad.Layout.ComboP
import XMonad.Layout.LayoutCombinators
import XMonad.Layout.Named
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Reflect
import XMonad.Layout.StackTile
import XMonad.Layout.Tabbed
import XMonad.Layout.TwoPane
import XMonad.Prompt
import XMonad.Util.EZConfig
import XMonad.Util.Run(spawnPipe)
import XMonad.Util.Scratchpad

import qualified XMonad.StackSet as W

import Control.Monad (liftM2)
import Data.List
import Data.Ratio
import System.IO

myLayout = desktopLayoutModifiers $
    onWorkspace "2:im/mail"  (stackTwoByOne ||| tiled ||| tabs) $
    onWorkspace "3:media" tabs $
    onWorkspace "4:vm" Full $
    accordianFull ||| tiled ||| stackTwo ||| tabs
  where
    accordianFull = named "Accordian/Full" (
        combineTwo (TwoPane (3/100) (1/2)) (Accordion) (Full))
    stackTwo = named "StackTwo" (
        combineTwo (StackTile 1 (3/100) (1/2)) (Full) (Full))
    stackTwoByOne = named "StackTwoByOne" (
        combineTwoP
            (StackTile 1 (3/100) (1/2))
            (Full)
            (TwoPane (3/100) (1/2))
            (Title "irssi"))
    tabs = named "Tabbed" (reflectHoriz $ tabbed shrinkText myTabConfig)
    tiled = named "Tiled" (reflectHoriz $ Tall 1 (3/100) (1/2))
    myTabConfig = defaultTheme {
      activeColor = "#222222",
      activeTextColor = "#aaaaaa",
      activeBorderColor = "#395571",
      inactiveColor = "#222222",
      inactiveTextColor = "#666666",
      inactiveBorderColor = "#343434",
      urgentColor = "#222222",
      urgentBorderColor = "#343434",
      urgentTextColor = "#bb4b4b"}

manageScratchPad :: ManageHook
manageScratchPad = scratchpadManageHook (W.RationalRect l t w h)
  where
    h = 0.1     -- terminal height, 10%
    w = 1       -- terminal width, 100%
    t = 1 - h   -- distance from top edge, 90%
    l = 1 - w   -- distance from left edge, 0%

avoidMaster :: W.StackSet i l a s sd -> W.StackSet i l a s sd
avoidMaster = W.modify' $ \c -> case c of
    W.Stack t [] (r:rs) ->  W.Stack t [r] rs
    otherwise           -> c

myManageHook = composeAll [
    currentWs =? "1:main"             --> doF avoidMaster,
    name      =? "irssi"              --> viewShift "2:im/mail",
    name      =? "mutt"               --> viewShift "2:im/mail",
    name      =? "player"             --> viewShift "3:media",
    className =? "Gimp"               --> viewShift "3:media",
    className =? "Openshot"           --> viewShift "3:media",
    className =? "qemu-system-x86_64" --> viewShift "4:vm",
    className =? "VirtualBox"         --> viewShift "4:vm",
    -- gimp insists on floating, so prevent that.
    role =? "gimp-image-window"       --> ask >>= doF . W.sink
  ] <+> manageScratchPad
  where
    name = stringProperty "WM_NAME"
    role = stringProperty "WM_WINDOW_ROLE"
    viewShift = doF . liftM2 (.) W.view W.shift

barBackground = "#232323"
barForeground = "#7e7e7e"

myTerminal = "urxvt"
myWorkspaces = ["1:main", "2:im/mail", "3:media", "4:vm", "5:misc", "6:misc"]

noScratchPad ws = if ws == "NSP" then "" else ws

main = do
  workspaceBar <- spawnPipe ("xmobar -B '" ++ barBackground ++ "'" ++ " -F '" ++ barForeground ++ "'")
  spawn "xset -b"
  spawn "xset r rate 250 30"
  spawn "xsetroot -cursor_name left_ptr"
  spawn "hsetroot -solid '#333333'"
  spawn "xmodmap ~/.Xmodmap"
  spawn "xrdb -load ~/.Xresources"
  spawn "synclient HorizTwoFingerScroll=1"
  spawn "pkill conky ; conky -c ~/.dzen/conkyrc | ~/bin/dzen2 -xp 40 -wp 60 -h 14 -ta r &"
  spawn "pkill dunst ; dunst -config ~/.dunstrc &"
  spawn "pkill keynav ; keynav &"
  spawn "pkill xcompmgr ; xcompmgr -c -r0 &"
  spawn "pkill -9 unclutter ; sleep 0.3 ; unclutter -idle 2 -root -noevents &"
  config <-
    withWindowNavigation(xK_k, xK_h, xK_j, xK_l) $
    withUrgencyHook NoUrgencyHook $
    ewmh $ desktopConfig {
      borderWidth        = 1,
      modMask            = mod1Mask,
      terminal           = myTerminal,
      normalBorderColor  = "#333333",
      focusedBorderColor = "#5884b0",
      workspaces         = myWorkspaces,
      manageHook         = manageDocks <+> myManageHook <+> manageHook desktopConfig,
      layoutHook         = myLayout,
      focusFollowsMouse  = False,
      logHook            = dynamicLogWithPP xmobarPP {
        ppOutput  = hPutStrLn workspaceBar,
        ppSep     = " | ",
        ppCurrent = xmobarColor "#5884b0" barBackground . wrap "[" "]",
        ppVisible = xmobarColor "#58738d" barBackground . wrap "[" "]",
        ppHidden  = xmobarColor barForeground barBackground . wrap "[" "]" . noScratchPad,
        ppLayout  = xmobarColor barForeground barBackground . wrap "{ " " }",
        ppTitle   = xmobarColor "#8eb157" barBackground . shorten 75,
        ppUrgent  = xmobarColor "#bb4b4b" barBackground . wrap "[" "]"
      } >> fadeInactiveLogHook 0.5 >> updatePointer (1,1) (1,1)
    }
    -- change workspace keybindings to not be "greedy" (move my focus to the
    -- screen displaying the workspace instead of moving the workspace to my
    -- screen)
    `additionalKeys` [((m .|. mod1Mask, k), windows $ f i)
         | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
         , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    `additionalKeysP` [
      ("M-x",         kill),
      ("M-m",         sendMessage $ JumpToLayout "Tabbed"),
      ("M-d",         sendMessage $ ToggleStruts),
      ("M-u",         focusUrgent),
      ("M-w",         cycleRecentWS [xK_Alt_L] xK_Tab xK_Tab),
      ("M-<Tab>",     bindOnLayout [
                          ("Tabbed", windows W.focusUp),
                          ("", windows W.focusDown)]),
      ("M-S-<Tab>",   bindOnLayout [
                          ("Tabbed", windows W.focusDown),
                          ("", windows W.focusUp)]),
      ("M-S-s",       withFocused $ windows . W.sink),
      ("M-p",         scratchpadSpawnActionTerminal myTerminal),
      ("M-v",         spawn $ "sleep .2 ; xdotool type --delay 0 --clearmodifiers \"$(xclip -o)\""),
      ("M-S-p",       spawn $ "~/bin/keyring prompt --paste"),
      ("M-t",         spawn $ "pkill stalonetray || stalonetray -bg '#232323' -i 16"),
      ("M-z",         spawn $ "alock -cursor theme:name=xtr -auth pam"),
      ("M-S-C-s",     spawn $ "~/bin/shutdown gui"),
      ("M-q",         spawn $ "xmonad --restart"),
      ("M-S-m",       spawn $ "~/bin/monitor external toggle ; xmonad --restart"),
      ("M-S-C-m",     spawn $ "~/bin/monitor refresh"),

      -- adjust screen brightness
      ("M-b",         spawn $ "xbacklight -inc 10"),
      ("M-S-b",       spawn $ "xbacklight -dec 10"),

      -- media mappings, mnemonics based on the shift version of the key:
      --   &   - pause/play
      --   *   - (un)mute
      --   <,> - prev/next track
      --   -,+ - increase/decrease volume
      ("M-7",         spawn $ "~/bin/player toggle"),
      ("M-.",         spawn $ "~/bin/player next"),
      ("M-,",         spawn $ "~/bin/player prev"),
      ("M-8",         spawn $ "~/bin/volume toggle"),
      ("M-=",         spawn $ "~/bin/volume 3+"),
      ("M--",         spawn $ "~/bin/volume 3-") ]
    `removeKeysP` [ ("M-r") ]

  xmonad config
