-- Need to figure out how to ensure dependencies
-- 1. SWS extensions
-- 2. Custom stopgo function


-- Todo: Configure Tracks (Start from a template?)
-- Todo: Configure Template(s)


-- Function to read the entire content of a file
function readFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil, "Unable to open file: " .. filePath
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Function to split a string by a delimiter
function split(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

-- Function to parse CSV content into a table
function parseCSV(csvContent)
    local rows = {}
    for line in csvContent:gmatch("[^\r\n]+") do
        local row = split(line, ",")
        table.insert(rows, row)
    end
    return rows
end

-- Main script
local filePath = "/Users/caseyerdmann/Desktop/ReaperSet.csv"
local content, err = readFile(filePath)
if not content then
    reaper.ShowMessageBox(err, "Error", 0)
    return
end

local parsedData = parseCSV(content)

-- Config Variables
local template = ""
local projects_path = ""
local projects_loc = {}
local song_names = {}

-- Print the parsed data
for i, row in ipairs(parsedData) do
    for j, cell in ipairs(row) do
        if j == 2 and i == 1 then
            template = cell

        elseif j == 2 and i == 2 then
            projects_path = cell

        elseif j == 1 and i > 2 then
            table.insert(song_names, cell)

        elseif j == 2 and i > 2 then
            table.insert(projects_loc, projects_path .. cell)
        end

        
        --reaper.ShowConsoleMsg(row)


    end
end

reaper.ShowConsoleMsg(template .. "\n")
reaper.ShowConsoleMsg(projects_path .. "\n")

for _, location in pairs(projects_loc) do 
    reaper.ShowConsoleMsg(location .. "\n")
end


    -- Copy tempo map from the original project
function getTempoMap(project)
    numTempos = reaper.CountTempoTimeSigMarkers(project)
    tempoMarkers = {}
    for i = 0, numTempos - 1 do
        local retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(project, i)
        table.insert(tempoMarkers, {timepos, bpm, timesig_num, timesig_denom, lineartempo})
    end
    return tempoMarkers
end

function setTempoMap(current_position, tempoMarkers, targetProject)
    -- Paste the copied tempo map

    for _, marker in ipairs(tempoMarkers) do
        reaper.SetTempoTimeSigMarker(targetProject, -1, marker[1] + current_position, -1, -1, marker[2], marker[3], marker[4], marker[5], false)
    end
end

local date_string = os.date("%Y-%m-%d_%H-%M-%S")
reaper.ShowConsoleMsg("\nPPATH CHECK" .. projects_path .. "\n")

local setlist = projects_path .. "setlists/" .. date_string .. "setlist.rpp"


reaper.Main_OnCommand(40859, 0)  -- New Project Tab

reaper.ShowConsoleMsg("\nTEMPCHECK" .. template .. "\n")
reaper.Main_openProject(template) -- Open the project template after opening a new tab

-- Configure Setlist Project
-- Set the timebase 
reaper.SNM_SetIntConfigVar("itemtimelock", 0)
reaper.SNM_SetIntConfigVar("tempoenvtimelock", 0)

reaper.Main_SaveProjectEx("setlist", setlist, 0)

for index, project in ipairs(projects_loc) do
    reaper.Main_openProject("noprompt:" .. project)

    local focus_command_id = reaper.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    reaper.Main_OnCommand(focus_command_id, 0) -- Focus arrange window before select & copy
    reaper.Main_OnCommand(40035, 0) -- Select all items in the current project
    reaper.Main_OnCommand(40698, 0) -- Copy all selected items

    tempoMap = getTempoMap(project)

    reaper.Main_openProject("noprompt:" .. setlist)

    local region_start = reaper.GetCursorPositionEx(setlist)

    reaper.Main_OnCommand(40043, 0)  -- Go to the end of the project
    setTempoMap(region_start, tempoMap, setlist)
    reaper.Main_OnCommand(41748, 0)  -- Paste items

    local region_end = reaper.GetCursorPositionEx(setlist)

    -- Pull project name from filepath for region name
    local filename_with_extension = project:match("^.+/(.+)$")
    local project_name = filename_with_extension:gsub("%.RPP$", "")
    reaper.AddProjectMarker(setlist, true, region_start, region_end, project_name, index)

    -- Replace with your custom command GUID of Transport: Stop + Regions: Go to next region after...
    stop_and_go_cmd = reaper.NamedCommandLookup("_42debd01be2b42acab5fa2fd0805492b")
    -- Add Stop Marker that stops playback and moves playhead to next region
    reaper.AddProjectMarker(setlist, false, region_end - 1, 0, "!" .. stop_and_go_cmd, index)

    reaper.Main_SaveProjectEx("setlist", setlist, 0)
end

reaper.Main_OnCommand(40042, 0)  -- Go to the start of the project
reaper.Main_SaveProjectEx("setlist", setlist, 0)

-- Horizontally zoom out until everything fits
reaper.Main_OnCommand(40296, 0) -- View: Zoom out project

-- Vertically zoom out until all tracks fit
reaper.Main_OnCommand(40295, 0) -- View: Zoom out project vertically

-- reaper.ShowConsoleMsg(region_end .. "\n")
