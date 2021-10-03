local { isPlatformPS4, isPlatformPS5 } = require("scripts/clientState/platform.nut")

const GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID = "gamepad_cursor_controls_splash_displayed"

class ::gui_handlers.GampadCursorControlsSplash extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controls/gamepadCursorControlsSplash.blk"

  // All contactPointX/contactPointY coords below are X/Y coords on the source image canvas (840 x 452 px).
  // Just open the image in any image viewer, point mouse anywhere on it, and it will display X/Y coords of
  // the mouse pointer on the image canvas. Those coords can be used here as contactPointX/contactPointY.

  controllerDualshock4View = {
    image = "#ui/images/controller/controller_dualshock4"
    isSwapDirpadAndLStickBubblesPos = false
    dirpad = {
      contactPointX = "168"
      contactPointY = "232"
    }
    leftStick = {
      contactPointX = "290"
      contactPointY = "349"
    }
    rightStick = {
      contactPointX = "549"
      contactPointY = "349"
    }
    actionKey = {
     contactPointX = "698"
     contactPointY = "284"
    }
  }

  controllerDualsenseView = {
    image = "#ui/images/controller/controller_dualsense"
    isSwapDirpadAndLStickBubblesPos = false
    dirpad = {
      contactPointX = "163"
      contactPointY = "239"
    }
    leftStick = {
      contactPointX = "289"
      contactPointY = "356"
    }
    rightStick = {
      contactPointX = "551"
      contactPointY = "356"
    }
    actionKey = {
     contactPointX = "702"
     contactPointY = "287"
    }
  }

  controllerXboxOneView = {
    image = "#ui/images/controller/controller_xbox_one"
    isSwapDirpadAndLStickBubblesPos = true
    dirpad = {
      contactPointX = "325"
      contactPointY = "334"
    }
    leftStick = {
      contactPointX = "191"
      contactPointY = "259"
    }
    rightStick = {
      contactPointX = "517"
      contactPointY = "387"
    }
    actionKey = {
     contactPointX = "635"
     contactPointY = "277"
    }
  }

  bubblesList = [ "dirpad", "lstick", "rstick", "actionx" ]

  static function open() {
    ::gui_start_modal_wnd(::gui_handlers.GampadCursorControlsSplash)
  }

  static function shouldDisplay() {
    // Possible values: int 2 (version 2 seen), bool true (version 1 seen), null (new account)
    local value = ::loadLocalByAccount(GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID)
    return value == true // Show it only to old accounts.
  }

  static function markDisplayed() {
    ::saveLocalByAccount(GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID, 2)
  }


  function initScreen()
  {
    local contentObj = scene.findObject("content")
    if (!::check_obj(contentObj))
      goBack()

    local view = isPlatformPS4 ? controllerDualshock4View
               : isPlatformPS5 ? controllerDualsenseView
               :                 controllerXboxOneView

    view.isGamepadCursorControlsEnabled <- ::g_gamepad_cursor_controls.getValue()

    local markUp = ::handyman.renderCached("gui/controls/gamepadCursorcontrolsController", view)
    guiScene.replaceContentFromText(contentObj, markUp, markUp.len(), this)

    local linkingObjsContainer = getObj("gamepad_image")
    local linesGeneratorConfig = {
      startObjContainer = linkingObjsContainer
      endObjContainer   = linkingObjsContainer
      lineInterval = "@helpLineInterval"
      links = bubblesList.map(@(id) { start = $"bubble_{id}", end = $"dot_{id}" })
    }
    local linesMarkup = ::LinesGenerator.getLinkLinesMarkup(linesGeneratorConfig)
    guiScene.replaceContentFromText(getObj("lines_block"), linesMarkup, linesMarkup.len(), this)
  }


  function goBack()
  {
    markDisplayed()
    base.goBack()
  }


  function getNavbarTplView()
  {
    return {
      right = [
        {
          text = "#msgbox/btn_ok"
          shortcut = "X"
          funcName = "goBack"
          button = true
        }
      ]
    }
  }
}
