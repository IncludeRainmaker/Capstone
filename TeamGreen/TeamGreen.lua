-- VECTRIC LUA SCRIPT

-- by D. Retterer
-- Creates contours that represent pins and sockets for finger joint
-- with left and right pins and sockets a specified (equal) width
-- and full sized pins and sockets sized based on the requested
-- number of them.

-- Store in C:\Users\Public\Documents\Vectric Files\Gadgets\Aspire V8.0 to make it
-- a gadget visible in Aspire V8.0

-- Origin is at the lower left corner of the workpiece

-- Based on an algorithm by Team Blue  (Merkel, et. al.)
-- require("mobdebug").start() -- starts the debugger

function main(path)

  -- Ensure that a job is loaded
  local job = VectricJob()

  if not job.Exists then
     DisplayMessageBox("No job open.")
     return false
  end

  dialog = HTML_Dialog(false, "file:" .. path .. "\\TeamGreen.htm", 450, 300, "Finger_Joints")
  dialog:AddIntegerField("NumberOfInteriorPins", 7)
  dialog:AddDoubleField("EndPinWidth", 0.625)
  dialog:AddDoubleField("EndmillDiameter", 0.25)
  dialog:AddDoubleField("Clearance", 0.005)
  dialog:ShowDialog()

  return true
end

function OnLuaButton_CreateFingerJoints()
  -- Sets the number of interior pins.
  local numInteriorPins = dialog:GetIntegerField("NumberOfInteriorPins")
  -- Sets the end pin width.
  local endPinWidth = dialog:GetDoubleField("EndPinWidth")
  -- Set the diameter of the bit. The Thing that does the actual
  local BitDiameter = dialog:GetDoubleField("EndmillDiameter")
  -- Sets the clearence for the pin
  local Clearance = dialog:GetDoubleField("Clearance")

  -- API Call to Vetric?
  local material_block = MaterialBlock()

  -- Height of the block.
  local Height = material_block.Height
  -- Width of the block.
  local Width = material_block.Width
  job = VectricJob() -- Creates a Vectric Job
  layer = job.LayerManager:GetActiveLayer() -- Gets the activated drawing

  pgen = PinGenerator:new()
  board = CuttingRectangle:new()
  board:setCuttingRectangle(0,0,Width, Height);
  SetNewLayerActive("SocketBoard");
  sb = pgen:GenerateSocketBoard(board, endPinWidth, numInteriorPins, Clearance, BitDiameter)
  CreateCutAreas(sb);
  SetNewLayerActive("PinBoard");
  pb = pgen:GeneratePinBoard(board, endPinWidth, numInteriorPins, Clearance, BitDiameter)
  CreateCutAreas(pb);
  return true
  end

function SetNewLayerActive(strLayerName)
  local layer = job.LayerManager:GetLayerWithName(strLayerName)
  job.LayerManager:SetActiveLayer(layer);
end

function ContourRectangle(start_point, width, height)
  -- Creates a rectangle contour with upper left corner of the rectangle
  -- at the start-point and the width and height as specified
  -- start_point: a Point2D object
  -- width: double
  -- height: double

  rectangle = Contour(0.0)
  rectangle:AppendPoint(start_point)
  rectangle:LineTo(Point2D(start_point.x + width, start_point.y))
  rectangle:LineTo(Point2D(start_point.x + width, start_point.y - height))
  rectangle:LineTo(Point2D(start_point.x, start_point.y - height))
  rectangle:LineTo(start_point)
  rectangle_object = CreateCadContour(rectangle)
  return rectangle_object
end

function CreateCutAreas(arrCutAreas)
  -- creates a rectangle for each CutArea in arrCutAreas

  local material_block = MaterialBlock()
  local Height = material_block.Height
  local Width = material_block.Width
  job = VectricJob()
  layer = job.LayerManager:GetActiveLayer()
  for i=1, #arrCutAreas, 1 do
    layer:AddObject(ContourRectangle(Point2D(arrCutAreas[i]['x'], arrCutAreas[i]['y']),
                                      arrCutAreas[i]['Width'],
                                      arrCutAreas[i]['Height']),true)
  end

  job:Refresh2DView()
  return true
end

CuttingRectangle = {
  x,
  y,
  Width,
  Height,

  setCuttingRectangle = function (self, _x, _y, _width, _height)
    self.x = _x
	  self.y = _y
    self.Width = _width
	  self.Height = _height
  end
}

function CuttingRectangle:new(o)
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  return o
end

PinGenerator = {
  GeneratePinBoard = function(self, board, endPinWidth, numOfInnerPins, clearance, endmill)
    --local numOfInnerPins = 2*numOfInnerPins + 1 -- DAR
    local output = {}
	  local input = self:GenerateAllSockets(board, endPinWidth, numOfInnerPins, clearance, endmill)
    for i=2, #input, 2 do
	    table.insert(output, input[i])
   end
   return output
  end,

  GenerateSocketBoard = function(self, board, endPinWidth, numOfInnerPins, clearance, endmill)
    --local numOfInnerPins = 2*numOfInnerPins + 1 -- DAR
    local output = {}
	  local input = self:GenerateAllSockets(board, endPinWidth, numOfInnerPins, clearance, endmill)
	  for i=1, #input, 2 do
	    table.insert(output, input[i])
	  end
    return output
  end,

  GenerateAllSockets = function(self, board, endPinWidth, numPins, clearance, endmill)
    local numPins = 2*numPins + 1
    local output = {}
	  local y = self:calculateY(endmill)
	  local height = self:calculateHeight(board.Height, endmill)
	  local endSocketWidth = self:calculateEndSocketWidth(endPinWidth, endmill, clearance)
	  local innerSocketWidth = self:GetSocketWidth(numPins, board.Width, clearance, endPinWidth)
	  local cr = CuttingRectangle:new()
	  cr:setCuttingRectangle(self:calculateLeftEndSocketX(endmill), y, endSocketWidth, height);
    table.insert(output,cr)
	  for i=1, numPins, 1 do
	    local x = endPinWidth + clearance -i*clearance + (innerSocketWidth * (i-1));
      cr = CuttingRectangle:new{}
      cr:setCuttingRectangle(x, y, innerSocketWidth, height)
	  table.insert(output, cr)
	  end
	  cr = CuttingRectangle:new{}
	  cr:setCuttingRectangle(self:calculateRightEndSocketX(endPinWidth, board.Width, clearance),
	                         y, endSocketWidth, height)
	  table.insert(output, cr)
	  return output
  end,

  -- get base pin length
  GetSocketWidth = function(self, numPins, boardWidth, clearance, endPinWidth)
	  local innerWidth = self:GetInnerWidth(boardWidth, clearance, endPinWidth)
    return (innerWidth / numPins + clearance)
  end,

  GetInnerWidth = function(self, boardWidth, clearance, endPinWidth)
    return boardWidth - endPinWidth * 2 - clearance
  end,

  -- get pin number
  GetPinNum = function(self, goalNum, isSymmetric)
    if (isSymmetric) then
      n = 1
    else
      n = 2
    end
	  while (goalNum - n >= 1) do
	    n = n+2
	  end

	  return n
  end,

  -- overload in C# but never used.
  -- GetInnerWidth = function(self, boardWidth, endPinWidth)
  --   return boardWidth - (2*endPinWidth)
  -- end,

  GetGoalNumber = function(self, goalWidth, innerWidth)
    return innerWidth / goalWidth
  end,

  -- get end pins
  calculateEndSocketWidth = function (self, endPinWidth, endMill, clearance)
    _width = endPinWidth + (endMill * 0.25) + clearance
	return _width
  end,

  calculateHeight = function(self, boardHeight, endMill)
	_height = boardHeight + endMill * 1.1
	return _height
  end,

  calculateLeftEndSocketX = function (self, endMill)
    _X1 = -endMill * 0.25
	return _X1
  end,

  calculateRightEndSocketX = function(self, endPinWidth, boardWidth, clearance)
    _X2 = boardWidth - endPinWidth - clearance
    return _X2
  end,

  calculateY = function(self, endMill)
    _Y = endMill*0.55
	return _Y
  end
}

function PinGenerator:new(o)
  -- Pin Generator object
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  return o
end

Breakpoints = {
  halfClearance,
  boardWidth,
  endPinWidth,
  numInteriorAreas,
  breakpoints = {},

  setParams = function (self, BoardWidth, Clearance, EndPinWidth, NumInteriorPins)
  breakpoints = {}
  halfClearance = Clearance/2
  boardWidth = BoardWidth
  endPinWidth = EndPinWidth
  numInteriorAreas = (NumInteriorPins * 2) + 1
  interiorBoardWidth = boardWidth - ((2 * endPinWidth) + Clearance)
  interPinWidth = interiorBoardWidth / numInteriorAreas
  end,

  generateBreakpoints = function (self)
    breakpoints = {}
    numBreakPoints = math.floor(numInteriorAreas / 2) + 1
    offset = endPinWidth + halfClearance
    table.insert(breakpoints, 0)
    table.insert(breakpoints, offset)
    for i=1, numInteriorAreas, 1 do
      offset = offset + interPinWidth
      table.insert(breakpoints, offset)
    end

    table.insert(breakpoints, boardWidth)
    return breakpoints
  end,
}

function Breakpoints:new(o,BoardWidth, Clearance, EndPinWidth, NumInteriorPins)

  o = o or {}
  setmetatable(o,self)
  self.__index = self
  Breakpoints:setParams(BoardWidth, Clearance, EndPinWidth, NumInteriorPins)
  Breakpoints:generateBreakpoints()
  return o
end


Board = {
  _Height,
  _Width,
  _emDiameter,
  _Clearance,
  cutAreas = {},

  setBoardParams = function(self, H, W, D, C)
      _Height = H
      _Width = W
      _emDiameter = D
      _Clearance = C
    end,

  generateSocketBoardBreaks = function (self)
    Breakpoints:generateBreakpoints()
    numItems = #breakpoints;
    newBreakPoints = {}
    for i=1, numItems, 1 do
      if math.fmod(i, 2) == 0 then
          newBreakPoints[i] = breakpoints[i] + halfClearance
      else
          newBreakPoints[i] = breakpoints[i] - halfClearance
      end
    end
    newBreakPoints[1] = newBreakPoints[1] - _Clearance
    newBreakPoints[numItems] = newBreakPoints[numItems] + _Clearance
    return newBreakPoints
 end,

  generateSocketBoardCutAreas = function (self)
      cutAreas = {}
      yStart = 0 + (0.5 * _emDiameter)
      yStop = -_Height - (0.5 * _emDiameter)
      Height = math.abs(yStart-yStop)
      socketBoardBreaks = self.generateSocketBoardBreaks()
      for i=1, #socketBoardBreaks, 2 do
        xStart = socketBoardBreaks[i]
        xStop = socketBoardBreaks[i+1]
        Width = math.abs(xStop-xStart)
        temp = CutArea:new()
        --temp.setRectangle({}, xStart, xStop, yStart, yStop)
        table.insert(cutAreas, temp.setRectangle({}, xStart, yStart, Width, Height))
      end
      return cutAreas
    end,

  generatePinBoardBreaks = function (self)
    Breakpoints:generateBreakpoints()
    numItems = #breakpoints;
    newBreakPoints = {}
    for i=1, numItems, 1 do
      if math.fmod(i, 2) == 0 then
          newBreakPoints[i] = breakpoints[i]
      else
          newBreakPoints[i] = breakpoints[i]
      end
    end
    return newBreakPoints
 end,

  generatePinBoardCutAreas = function (self)
      cutAreas = {}
      yStart = 0 + (0.5 * _emDiameter)
      yStop = -_Height - (0.5 * _emDiameter)
      Height = math.abs(yStart-yStop)
      pinBoardBreaks = self.generatePinBoardBreaks()
      for i=2, #pinBoardBreaks-1, 2 do
        xStart = pinBoardBreaks[i]
        xStop = pinBoardBreaks[i+1]
        Width = math.abs(xStop-xStart)
        temp = CutArea:new()
        --temp.setRectangle({}, xStart, xStop, yStart, yStop)
        table.insert(cutAreas, temp.setRectangle({}, xStart, yStart, Width, Height))
      end
      return cutAreas
    end
  }

function Board:new(o)
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  return o
end

Tool = {
  diameter,
  setDiameter = function (self, d)
    diameter = self.d;
  end
}

function Tool:new(o)
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  return o
  end


CutArea = {
  rect = {},
  setRectangle = function(self, ulcx, ulcy, width, height)
    rect = {ulcx, ulcy, width, height}
    return rect
  end
}

function CutArea:new(o)
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  return o
end
