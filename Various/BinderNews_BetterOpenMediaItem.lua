local reaper = reaper
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local U = assert(loadfile(script_path.."/../bn/util.lua")())

local opt = {
  verticalZoom = 6,
  horizontalZoom = 2,
  zoomIfEmpty = false,
}

local function MIDIAction(commandId, editor)
  local ed = editor or reaper.MIDIEditor_GetActive()
  return reaper.MIDIEditor_OnCommand(ed, commandId)
end

function main()
  local item = reaper.GetSelectedMediaItem(0, 0)
  if item == nil then return end
  local take = reaper.GetActiveTake(item)
  if take == nil then return end -- TODO ???
  local pcm = reaper.GetMediaItemTake_Source(take)
  local subProj = reaper.GetSubProjectFromSource(pcm)
  
  --U.msgfmt("MIDI: %s, PCM: %s, SubProj: %s", U.str(reaper.TakeIsMIDI(take)), U.str(pcm), U.str(subProj))
  
  -- MIDI take
  if reaper.TakeIsMIDI(take) then
    local s = { delay = 0, index = 1 }
    
    local function loop()
      if s.delay > 0 then
        s.delay = s.delay - 1
        reaper.defer(loop)
        return
      end
      
      if     s.index == 1 then
        reaper.Main_OnCommand(40153, 0) -- Open in built-in MIDI editor
        
      elseif s.index == 2 then
        local ed = reaper.MIDIEditor_GetActive()
        -- First we zoom to the content area
        MIDIAction(40466, ed) -- Zoom to content
        -- By unselecting all notes, we ensure the zoom out works properly
        MIDIAction(40214, ed) -- Unselect all
        
        -- only zoom out if not empty
        local _,notecnt,_,_ = reaper.MIDI_CountEvts(take)
        if notecnt > 0 or opt.zoomIfEmpty then
          for i = 1,opt.verticalZoom do
            MIDIAction(40112, ed) -- Zoom out vertically
          end
          for i = 1,opt.horizontalZoom do
            MIDIAction(1011, ed) -- Zoom out horizontally
          end
        end
        
      elseif s.index == 3 then
        s.index = -1
      end
      
      -- Ending code
      s.index = s.index + 1
      if s.index > 0 then reaper.defer(loop) end
    end
    reaper.defer(loop)
    
  -- Sub-project
  elseif subProj then
    reaper.SelectProjectInstance(subProj)
    
  -- Audio item
  elseif pcm then
    reaper.Main_OnCommand(40009, 0) -- Show media item/take properties
  end
end

main()
