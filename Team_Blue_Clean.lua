-- VECTRIC LUA SCRIPT

-- by D. Retterer (rewrite by M. Bishop)
-- Creates contours that represent pins and sockets for finger joint
-- with left and right pins and sockets a specified (equal) width 
-- and full sized pins and sockets sized based on the requested
-- number of them.  

-- Store in C:\Users\Public\Documents\Vectric Files\Gadgets\Aspire V8.0 to make it 
-- a gadget visible in Aspire V8.0

-- Origin is at the lower left corner of the workpiece

-- Based on an algorithm by Team Blue  (Merkel, et. al.)
--require("mobdebug").start() -- starts the debugger

function main(path)
  
  -- Ensure that a job is loaded
  local job = VectricJob()

  if not job.Exists then
    DisplayMessageBox('No job open.')
    return false
  end
    
  dialog = HTML_Dialog(false, 'file:' .. path .. '\\Team_Blue_Clean.htm', 450, 
                       300, 'Finger_Joints')
  dialog:AddIntegerField('NumberOfInteriorPins', 7)
  dialog:AddDoubleField('EndPinWidth', 0.625)
  dialog:AddDoubleField('EndmillDiameter', 0.25)
  dialog:AddDoubleField('Clearance', 0.005)
  dialog:ShowDialog()
  
  return true
end

function OnLuaButton_CreateFingerJoints()
  local num_interior_pins = dialog:GetIntegerField('NumberOfInteriorPins')
  local end_pin_width = dialog:GetDoubleField('EndPinWidth')
  local bit_diameter = dialog:GetDoubleField('EndmillDiameter')
  local clearance = dialog:GetDoubleField('Clearance')
  
  local material_block = MaterialBlock()
  local height = material_block.Height
  local width = material_block.Width
  --local full_pin_width = (width - 2 * end_pin_width)
  --local bit_radius = bit_diameter / 2
  
  job = VectricJob()
  layer = job.LayerManager:GetActiveLayer()
  
  my_board = Board:new()
  my_board:set_board_params(height, width, bit_diameter, clearance) 
  breaks = Breakpoints:new({}, width, clearance, end_pin_width, num_interior_pins)
  socket_cut_area = my_board:generate_socket_board_cut_areas(breaks) 
  SetNewLayerActive('SocketBoard')
  create_cut_areas(socket_cut_area) -- Create cut areas for socket board
  pin_cut_area = my_board:generate_pin_board_cut_areas(breaks)
  SetNewLayerActive('PinBoard')
  create_cut_areas(pin_cut_area)
  return true
end

function SetNewLayerActive(strLayerName)
  local layer = job.LayerManager:GetLayerWithName(strLayerName)
  job.LayerManager:SetActiveLayer(layer)
end

function contour_rectangle(start_point, width, height)
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

function create_cut_areas(arr_cut_areas)
  -- creates a rectangle for each Cut_Area in arr_cut_areas
  
  local material_block = MaterialBlock()
  --local height = material_block.Height
  --local width = material_block.Width
  job = VectricJob()
  layer = job.LayerManager:GetActiveLayer()
  for i = 1, #arr_cut_areas, 1 do
    layer:AddObject(contour_rectangle(Point2D(arr_cut_areas[i][1], arr_cut_areas[i][2]),
                                              arr_cut_areas[i][3], arr_cut_areas[i][4]), true)
                                      
  end
  
  job:Refresh2DView()
  return true
end

Breakpoints = {
   half_clearance,
   board_width,
   end_pin_width,
   num_interior_areas,
   breakpoints = {},
  
   set_params = function(self, board_width_param, clearance, end_pin_width_param, 
                         num_interior_pins)
    breakpoints = {}
    half_clearance = clearance / 2
    board_width = board_width_param
    end_pin_width = end_pin_width_param
    num_interior_areas = (num_interior_pins * 2) + 1
    interior_board_width = board_width - ((2 * end_pin_width) + clearance)
    inter_pin_width = interior_board_width / num_interior_areas
  end,
  
   generate_breakpoints = function(self)
    breakpoints = {}
    --num_breakpoints = math.floor(num_interior_areas / 2) + 1
    offset = end_pin_width + half_clearance
    table.insert(breakpoints, 0)
    table.insert(breakpoints, offset)
    for i = 1, num_interior_areas, 1 do
      offset = offset + inter_pin_width
      table.insert(breakpoints, offset)
    end
    
    table.insert(breakpoints, board_width)
    return breakpoints
  end
}

function Breakpoints:new(o, board_width, clearance, end_pin_width, num_interior_pins)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  Breakpoints:set_params(board_width, clearance, end_pin_width, num_interior_pins)
  Breakpoints:generate_breakpoints()
  return o
end

Board = {
  _height,
  _width,
  _em_diameter,
  _clearance,
  cutAreas = {},
  
   set_board_params = function(self, h, w, d, c)
      _height = h
      _width = w
      _em_diameter = d
      _clearance = c
      end,
      
   generate_socket_board_breaks = function(self)
    Breakpoints:generate_breakpoints()
    local num_items = #breakpoints
    new_breakpoints = {}
    for i = 1, num_items, 1 do
      if math.fmod(i, 2) == 0 then
          new_breakpoints[i] = breakpoints[i] + half_clearance
      else
          new_breakpoints[i] = breakpoints[i] - half_clearance
      end
    end
    
    new_breakpoints[1] = new_breakpoints[1] - _clearance
    new_breakpoints[num_items] = new_breakpoints[num_items] + _clearance
    return new_breakpoints
  end,
  
   generate_socket_board_cut_areas =  function(self)
    cutAreas = {}
    local y_start = 0 + (0.5 * _em_diameter)
    local y_stop = -_height - (0.5 * _em_diameter)
    local height = math.abs(y_start - y_stop)
    local socket_board_breaks = self.generate_socket_board_breaks()
    for i = 1, #socket_board_breaks, 2 do
      local x_start = socket_board_breaks[i]
      local x_stop = socket_board_breaks[i+1]
      width = math.abs(x_stop - x_start)
      temp = CutArea:new()
      table.insert(cutAreas, temp.set_rectangle({}, x_start, y_start, width, height))
    end
    
    return cutAreas
  end,
  
   generate_pin_board_breaks = function (self)
    Breakpoints:generate_breakpoints()
    local num_items = #breakpoints
    new_breakpoints = {}
    for i = 1, num_items, 1 do
      if math.fmod(i, 2) == 0 then
        new_breakpoints[i] = breakpoints[i]
      else
        new_breakpoints[i] = breakpoints[i]
      end
    end
    
    return new_breakpoints  
  end,
  
   generate_pin_board_cut_areas = function (self)
    cutAreas = {}
    local y_start = 0 + (0.5 * _em_diameter)
    local y_stop = -_height - (0.5 * _em_diameter)
    local height = math.abs(y_start - y_stop)
    pin_board_breaks = self.generate_pin_board_breaks()
    for i = 2, #pin_board_breaks - 1, 2 do
      local x_start = pin_board_breaks[i]
      local x_stop = pin_board_breaks[i+1]
      local width = math.abs(x_stop - x_start)
      temp = CutArea:new()
      table.insert(cutAreas, temp.set_rectangle({}, x_start, y_start, width, height))
    end
    
    return cutAreas
  end
}

function Board:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

Tool = {
diameter,
  set_diameter = function(self, d)
  diameter = self.d
end
}

function Tool:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

CutArea = {
rect = {},
set_rectangle = function(self, ulcx, ulcy, width, height)
  rect = {ulcx, ulcy, width, height}
  return rect
end
}

function CutArea:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end


