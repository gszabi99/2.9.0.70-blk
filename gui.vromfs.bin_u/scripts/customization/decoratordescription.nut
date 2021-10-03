local skinLocations = require("scripts/customization/skinLocations.nut")

local function updateDecoratorDescription(obj, handler, decoratorType, decorator, params = {}) {
  local config = null
  local unlockBlk = g_unlocks.getUnlockById(decorator?.unlockId)
  if (unlockBlk)
  {
    config = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(config)
  }

  local iObj = obj.findObject("image")
  local img = params?.useBigImg ? decoratorType.getBigImage(decorator) : decoratorType.getImage(decorator)

  iObj["background-image"] = img

  if (img != "")
  {
    local imgSize = params?.imgSize ?? {}
    local imgRatio = decoratorType.getRatio(decorator)
    local iDivObj = iObj.getParent()
    iDivObj.height = imgSize?[1] ?? ::format("%d*@decalIconHeight", ((imgRatio < 3) ? 2 : 1))
    iDivObj.width  = imgSize?[0] ?? $"{imgRatio}h"
    iDivObj.show(true)
  }

  local header = decorator.getName()
  obj.findObject("header").setValue(header)

  local desc = [decorator.getDesc()]
  if (config?.isRevenueShare ?? false)
    desc.append(::colorize("advertTextColor", ::loc("content/revenue_share")))

  local typeDesc = decorator.getTypeDesc()
  typeDesc = (desc.len() > 1 || desc[0].len() > 0) ? $"\n{typeDesc}" : typeDesc
  desc.append(typeDesc, decorator.getVehicleDesc(),
    decorator.getLocParamsDesc(), decorator.getRestrictionsDesc())

  local commaLoc = ::loc("ui/comma")
  local colonLoc = ::loc("ui/colon")
  local searchId = decorator.id
  if (decoratorType.hasLocations(searchId))
  {
    local mask = skinLocations.getSkinLocationsMaskBySkinId(searchId, false)
    local locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (locations.len())
      desc.append($"{::loc("camouflage/for_environment_conditions")}{colonLoc}{commaLoc.join(locations, true)}")
  }

  local tags = decorator.getTagsLoc()
  if (tags.len())
  {
    tags = ::u.map(tags, @(txt) ::colorize("activeTextColor", txt))
    desc.append($"\n{::loc("ugm/tags")}{colonLoc}{commaLoc.join(tags, true)}")
  }

  local descText = "\n".join(desc, true)
  local warbondId = ::getTblValue("wbId", params)
  if (warbondId)
  {
    local warbond = ::g_warbonds.findWarbond(warbondId, ::getTblValue("wbListId", params))
    local award = warbond? warbond.getAwardById(searchId) : null
    if (award)
      descText = award.addAmountTextToDesc(descText)
  }
  obj.findObject("description").setValue(descText)

  local isDefaultSkin = ::g_unlocks.isDefaultSkin(searchId)
  local isTrophyContent  = params?.showAsTrophyContent ?? false
  local isReceivedPrizes = params?.receivedPrizes      ?? false

  local canBuy = false
  local isAllowed = decoratorType.isPlayerHaveDecorator(searchId)
  if (!isAllowed)
  {
    local cost = decorator.getCost()
    local hasPrice = !isTrophyContent && !isReceivedPrizes && !cost.isZero()
    local aObj = ::showBtn("price", hasPrice, obj)
    if (hasPrice)
    {
      canBuy = true
      if (::check_obj(aObj))
        aObj.setValue(::loc("ugm/price") + ::loc("ui/colon") + ::colorize("white", cost.getTextAccordingToBalance()))
    }
  } else
    ::showBtn("price", false, obj)

  local canConsumeCoupon = false
  local canFindOnMarketplace = false
  if (!isAllowed && decorator.getCouponItemdefId() != null)
  {
    local inventoryItem = ::ItemsManager.getInventoryItemById(decorator.getCouponItemdefId())
    if (inventoryItem?.canConsume() ?? false)
      canConsumeCoupon = true
    canFindOnMarketplace = !canConsumeCoupon
  }

  //fill unlock info
  local cObj = obj.findObject("conditions")
  cObj.show(true)

  local iconName = isDefaultSkin ? ""
    : isAllowed ? "favorite"
    : "locked"

  local canShowProgress = !isTrophyContent && !isReceivedPrizes
  local conditionsText = canShowProgress && config ?
    ::UnlockConditions.getConditionsText(config.conditions, config.curVal, config.maxVal) : ""

  if (!isDefaultSkin && conditionsText == "")
  {
    if (isAllowed)
    {
      conditionsText = ::loc("mainmenu/itemReceived")
      if (isTrophyContent && !isReceivedPrizes)
        conditionsText += "\n" + ::colorize("badTextColor",
          ::loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"))
    }
    else if (isTrophyContent)
      conditionsText = ::loc("mainmenu/itemCanBeReceived")
    else if (canBuy)
      conditionsText = ::loc("shop/object/can_be_purchased")
    else if (canConsumeCoupon)
      conditionsText = " ".concat(::loc("currency/gc/sign/colored"),
        ::colorize("currencyGCColor", ::loc("shop/object/can_get_from_coupon")))
    else if (canFindOnMarketplace)
      conditionsText = " ".concat(::loc("currency/gc/sign/colored"),
        ::colorize("currencyGCColor", ::loc("shop/object/can_be_found_on_marketplace")))
    else
      conditionsText = ::loc("multiplayer/notAvailable")
  }

  local dObj = cObj.findObject("unlock_description")
  dObj.setValue(conditionsText)

  local canShowProgressBar = !isAllowed && canShowProgress && config
  if (canShowProgressBar)
  {
    local progressData = config.getProgressBarData()
    canShowProgressBar = progressData.show
    local pObj = ::showBtn("progress", canShowProgressBar, cObj)
    if (canShowProgressBar)
      pObj.setValue(progressData.value)
  } else
    ::showBtn("progress", false, cObj)

  if (iconName != "")
    iconName = ::format("#ui/gameuiskin#%s", iconName)
  cObj.findObject("state")["background-image"] = iconName

  local additionalDescriptionMarkup = params?.additionalDescriptionMarkup
  dObj = ::showBtn("additional_description", additionalDescriptionMarkup != null, obj)
  if (additionalDescriptionMarkup != null)
    dObj.getScene().replaceContentFromText(dObj, additionalDescriptionMarkup, additionalDescriptionMarkup.len(), handler)
}

return {
  updateDecoratorDescription = updateDecoratorDescription
}