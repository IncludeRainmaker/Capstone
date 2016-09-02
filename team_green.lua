------------------------------------------------------------
-- VECTRIC LUA SCRIPT
-- AUTHOR(S): Prof. Dave Retterer  <d-retterer@onu.edu>
--            Austin M. Rademacher <a-rademacher@onu.edu>
--            TeamGreen Software Engineering 2016
-- DESCRIPTION: This fun
------------------------------------------------------------

function main(path)

  -- Makes the job load locally.
  local job = VectricJob()

  -- If a job doesn't excist then it will tell the user no job is created.
  if not job.Exists then
    DisplayMessageBox("No Job open.")
  end

  -- Creates a dialog
  dialog = HTML_Dialog(false, "file:" .. path .. "\\TeamGreen.htm", 450, 300, "Finger_Joints")

  -- Populates Default Values
  dialog:AddIntegerField("NumberOfInteriorPins", 7)
  dialog:AddIntegerField("EndPinWidth", 0.625)
  dialog:AddIntegerField("EndmillDiameter", 0.005)
  dialog:AddIntegerField("Clearance", 0.25)

  return true
end
