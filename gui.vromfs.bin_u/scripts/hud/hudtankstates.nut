local hudTankStates = require("hudTankStates")
local { hudTankMovementStatesVisible } = require("scripts/hud/hudConfigByGame.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

enum ORDER //order for movement state info
{
  GEAR
  RPM
  CRUISE_CONTROL
  SPEED
}

local tankStatesByObjId = {
  stabilizer = {
    objName = "stabilizer"
    updateConfigs = [{
      watch = hudTankStates.getStabilizerObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("stabilizer").state = value == 0 ? "off" : "on"
    }]
  }
  lws = {
    objName = "lws"
    updateConfigs = [{
      watch = hudTankStates.getLwsObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("lws").state = value == 0 ? "off" : "on"
    }]
  }
  ircm = {
    objName = "ircm"
    updateConfigs = [{
      watch = hudTankStates.getIrcmObservable()
      isVisible = @(value) value != -1
      updateObj = @(obj, value) obj.findObject("ircm").state = value == 3 ? "off" : value == 2 ? "dmg" : "on"
    }]
  }
  gear = {
    objName = "gear"
    orderView = ORDER.GEAR
    getLocName = @() ::loc("HUD/GEAR_SHORT")
    updateConfigs = [{
      watch = hudTankStates.getGearObservable()
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
    }]
  }
  rpm = {
    objName = "rpm"
    orderView = ORDER.RPM
    getLocName = @() ::loc("HUD/RPM_SHORT")
    updateConfigs = [{
      watch =  hudTankStates.getRpmObservable()
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value.tostring())
    }]
  }
  speed = {
    objName = "speed"
    orderView = ORDER.SPEED
    getLocName = @() ::loc("HUD/REAL_SPEED_SHORT")
    updateConfigs = [{
        watch = hudTankStates.getSpeedObservable()
        updateObj = @(obj, value) obj.findObject("state_value").setValue(
          "".concat(value.tostring(), " ", ::g_measure_type.SPEED.getMeasureUnitsName()))
      },
      {
        objName = "speed"
        watch = hudTankStates.getHasSpeedWarningObservable()
        updateObj = @(obj, value) obj.findObject("state_value").overlayTextColor = value ? "bad" : ""
      }]
   }

  driving_direction_mode = {
    objName = "driving_direction_mode"
    updateConfigs = [{
      watch = hudTankStates.getDrivingDirectionMode()
      updateObj = @(obj, value) obj.state = value ? "on" : "off"
    }]
  }

  cruise_control = {
    objName = "cruise_control"
    orderView = ORDER.CRUISE_CONTROL
    getLocName = @() ::loc("HUD/CRUISE_CONTROL_SHORT")
    updateConfigs = [{
      watch = hudTankStates.getCruiseControl()
      isVisible = @(value) value != ""
      updateObj = @(obj, value) obj.findObject("state_value").setValue(value)
    }]
  }

  first_stage_ammo = {
    objName = "first_stage_ammo"
    updateConfigs = [{
      watch = hudTankStates?.getFirstStageAmmo()
      isVisible = @(value) value >= 0
      updateObj = function(obj, value) {
        obj.state = value > 0 ? "" : "dead"
        obj.findObject("state_value").setValue(value.tostring())
      }
    }]
  }
}

local function updateState(obj, watchConfig, value) {
  local isVisible = watchConfig?.isVisible(value) ?? true
  if (!::check_obj(obj))
    return
  obj.show(isVisible)
  if (!isVisible)
    return

  watchConfig.updateObj(obj, value)
}

local function getValueForObjUpdate(updateConfigs) {
  local stateValue = []
  foreach (updateConfig in updateConfigs) {
    local config = updateConfig
    local watch = config.watch
    if (watch == null)
      continue

    stateValue.append({
      watch = watch
      updateFunc = @(obj, value) updateState(obj, config, value)
    })
  }

  if (stateValue.len() == 0)
    return -1

  return stashBhvValueConfig(stateValue)
}

local function getMovementViewArray() {
  local statesArray = []
  foreach (id, state in tankStatesByObjId) {
    if (!(id in hudTankMovementStatesVisible.value) || state?.orderView == null)
      continue

    local stateValue = getValueForObjUpdate(state.updateConfigs)
    if (stateValue == "")
      continue

    statesArray.append({
      stateId = state.objName
      stateName = state.getLocName()
      orderView = state.orderView
      stateValue = stateValue
      })
  }
  statesArray.sort(@(a, b) a.orderView <=> b.orderView)
  return statesArray
}

local function showHudTankMovementStates(scene) {
  local movementStatesObj = scene.findObject("hud_movement_info")
  if (!::check_obj(movementStatesObj))
    return

  local blk = ::handyman.renderCached("gui/hud/hudTankMovementInfo", {tankStates = getMovementViewArray()})
  guiScene.replaceContentFromText(movementStatesObj, blk, blk.len(), this)
}

local getConfigValueById = @(objName) getValueForObjUpdate(tankStatesByObjId?[objName].updateConfigs ?? [])

return {
  showHudTankMovementStates = showHudTankMovementStates
  getConfigValueById = getConfigValueById
}

