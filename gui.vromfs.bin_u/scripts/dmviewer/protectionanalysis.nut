local protectionAnalysisOptions = require("scripts/dmViewer/protectionAnalysisOptions.nut")
local protectionAnalysisHint = require("scripts/dmViewer/protectionAnalysisHint.nut")
local { hasFeature } = require("scripts/user/features.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local controllerState = require("controllerState")
local { hangar_protection_map_update, protection_map_reset,
  set_protection_map_y_nulling, get_protection_map_progress } = require("hangarEventCommand")


local switch_damage = false
local allow_cutting = false

const CB_PROTECTION_MAP = "protectionAnalysis/cbProtectionMapValue"
const CB_VERTICAL_ANGLE = "protectionAnalysis/cbVerticalAngleValue"

class ::gui_handlers.ProtectionAnalysis extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.BASE
  sceneBlkName = "gui/dmViewer/protectionAnalysis.blk"
  sceneTplName = "gui/options/verticalOptions"

  protectionAnalysisMode = ::DM_VIEWER_PROTECTION
  hintHandler = null
  unit = null

  getSceneTplContainerObj = @() scene.findObject("options_container")
  function getSceneTplView()
  {
    protectionAnalysisOptions.setParams(unit)

    local view = { rows = [] }
    foreach (o in protectionAnalysisOptions.types)
      if (o.isVisible())
        view.rows.append({
          id = o.id
          name = o.getLabel()
          option = o.getControlMarkup()
          infoRows = o.getInfoRows()
          valueWidth = o.valueWidth
        })
    return view
  }

  function initScreen()
  {
    ::enableHangarControls(true)
    ::dmViewer.init(this)
    ::hangar_focus_model(true)
    guiScene.performDelayed(this, @() ::hangar_set_dm_viewer_mode(protectionAnalysisMode))
    setSceneTitle(::loc("mainmenu/btnProtectionAnalysis") + " " +
      ::loc("ui/mdash") + " " + ::getUnitName(unit.name))

    onUpdateActionsHint()

    guiScene.setUpdatesEnabled(false, false)
    protectionAnalysisOptions.init(this, scene)
    guiScene.setUpdatesEnabled(true, true)

    ::g_hud_hitcamera.init(scene.findObject("dmviewer_hitcamera"))

    hintHandler = protectionAnalysisHint.open(scene.findObject("hint_scene"))
    registerSubHandler(hintHandler)

    switch_damage = true //value is off by default it will be changed in AllowSimulation
    allow_cutting = false

    scene.findObject("checkboxSaveChoice").setValue(protectionAnalysisOptions.isSaved)

    local isShowProtectionMapOptions = hasFeature("ProtectionMap")
    local cbProtectionMapObj = ::showBtn("checkboxProtectionMap", isShowProtectionMapOptions)
    local cbVerticalAngleObj = ::showBtn("checkboxVerticalAngle", isShowProtectionMapOptions)
    ::showBtn("rowSeparator", isShowProtectionMapOptions)
    if (isShowProtectionMapOptions)
    {
      cbProtectionMapObj.setValue(::load_local_account_settings(CB_PROTECTION_MAP, false))
      cbVerticalAngleObj.setValue(::load_local_account_settings(CB_VERTICAL_ANGLE, false))
    }

    local isSimulationEnabled = unit?.unitType.canShowVisualEffectInProtectionAnalysis() ?? false
    local obj = showSceneBtn("switch_damage", isSimulationEnabled)
    if (isSimulationEnabled)
      onAllowSimulation(obj)

    ::allowCuttingInHangar(false)
  }

  onSave = @(obj) protectionAnalysisOptions.isSaved = obj?.getValue()

  function onChangeOption(obj)
  {
    if (!::check_obj(obj))
      return
    protectionAnalysisOptions.get(obj.id).onChange(this, scene, obj)
  }

  onButtonInc = @(obj) onProgressButton(obj, true)
  onButtonDec = @(obj) onProgressButton(obj, false)
  onDistanceInc = @(obj) onButtonInc(scene.findObject("buttonInc"))
  onDistanceDec = @(obj) onButtonDec(scene.findObject("buttonDec"))

  function onProgressButton(obj, isIncrement)
  {
    if (!::check_obj(obj))
      return
    local optionId = ::g_string.cutPrefix(obj.getParent().id, "container_", "")
    local option = protectionAnalysisOptions.get(optionId)
    local value = option.value + (isIncrement ? option.step : - option.step)
    scene.findObject(option.id).setValue(value)
  }

  function onWeaponsInfo(obj)
  {
    ::open_weapons_for_unit(unit, { needHideSlotbar = true })
  }

  function goBack()
  {
    ::hangar_focus_model(false)
    ::hangar_set_dm_viewer_mode(::DM_VIEWER_NONE)
    ::repairUnit()
    ::save_local_account_settings(CB_PROTECTION_MAP,
      scene.findObject("checkboxProtectionMap")?.getValue())
    ::save_local_account_settings(CB_VERTICAL_ANGLE,
      scene.findObject("checkboxVerticalAngle")?.getValue())
    base.goBack()
  }

   function onRepair()
  {
    ::repairUnit()
  }

  function onAllowSimulation(sObj)
  {
    if (::check_obj(sObj))
    {
      switch_damage = !switch_damage
      ::allowDamageSimulationInHangar(switch_damage)

      showSceneBtn("switch_cut", switch_damage)
      showSceneBtn("btn_repair", switch_damage)
    }
  }

  function onAllowCutting(sObj)
  {
    if (::check_obj(sObj))
    {
      allow_cutting = !allow_cutting
      ::allowCuttingInHangar(allow_cutting)
    }
  }

  function onUpdateActionsHint()
  {
    local showHints = ::has_feature("HangarHitcamera")
    local hObj = showSceneBtn("analysis_hint", showHints)
    if (!showHints || !::check_obj(hObj))
      return

    //hint for simulate shot
    local showHint = ::has_feature("HangarHitcamera")
    local bObj = showSceneBtn("analysis_hint_shot", showHint)
    if (showHint && ::check_obj(bObj))
    {
      local shortcuts = []
      if (::show_console_buttons)
        shortcuts.append(::loc("xinp/R2"))
      if (controllerState?.is_mouse_connected())
        shortcuts.append(::loc("key/LMB"))
      bObj.findObject("push_to_shot").setValue(::g_string.implode(shortcuts, ::loc("ui/comma")))
    }
  }

  function buildProtectionMap()
  {
    local waitTextObj = scene.findObject("pa_wait_text")
    local cbVerticalAngleObj = scene.findObject("checkboxVerticalAngle")
    if (!waitTextObj?.isValid() || !cbVerticalAngleObj?.isValid())
      return

    hangar_protection_map_update()
    SecondsUpdater(waitTextObj, function(timerObj, p) {
        local progress = get_protection_map_progress()
        if (progress < 100)
          timerObj.setValue($"{progress.tostring()}%")
        else {
          ::showBtn("pa_info_block", false)
          p.cbVerticalAngleObj.enable = "yes"
        }
      }, false, {cbVerticalAngleObj})
  }

  function toggleProtectionMap(state)
  {
    local cbVerticalAngleObj = scene.findObject("checkboxVerticalAngle")
    if (cbVerticalAngleObj?.isValid())
      cbVerticalAngleObj.enable = state ? "no" : "yes"
    ::showBtn("pa_info_block", state)
    if (!state)
      protection_map_reset()
    else
      buildProtectionMap()
  }

  onProtectionMap = @(obj) toggleProtectionMap(obj.getValue())
  function onConsiderVerticalAngle(obj)
  {
    set_protection_map_y_nulling(obj.getValue())
    toggleProtectionMap(scene.findObject("checkboxProtectionMap")?.getValue() ?? false)
  }
}

return {
  canOpen = function(unit) {
    return ::has_feature("DmViewerProtectionAnalysis")
      && ::isInMenu()
      && !::SessionLobby.hasSessionInLobby()
      && unit?.unitType.canShowProtectionAnalysis() == true
  }

  open = function (unit) {
    if (!canOpen(unit))
        return
    ::handlersManager.loadHandler(::gui_handlers.ProtectionAnalysis, { unit = unit })
  }
}
