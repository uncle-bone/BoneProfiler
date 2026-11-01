-- BoneProfiler 1.0.2 / WoW 3.3.5a. No external libraries.
local A = CreateFrame('Frame', 'BoneProfilerFrame', UIParent)
local floor, format, sort, max = math.floor, string.format, table.sort, math.max
local tinsert, tremove = table.insert, table.remove
local now = GetTime
local db, session, elapsed, lastSample, lastCpu, lastMem, nextRefresh = nil, {}, 0, 0, {}, {}, 0
local spikeThreshold, samplePeriod, maxSamples = 100, 1, 900
local profiling = GetCVar('scriptProfile') == '1'
local cpuAPI = type(GetAddOnCPUUsage)=='function' and type(UpdateAddOnCPUUsage)=='function'
local cpuObserved = false
local episodeStart, episodeLow, episodeMin, episodeMem = nil, 0, 999, 0
local episodes = {}
local function cpuStatus() return 'CVar='..tostring(GetCVar('scriptProfile'))..', API='..(cpuAPI and 'available' or 'missing') end
local function say(s) DEFAULT_CHAT_FRAME:AddMessage('|cff55bbffBoneProfiler:|r '..s) end
local function safe(f, ...) if type(f)~='function' then return nil end local ok, result = pcall(f, ...); if ok then return result end end
local function round(x) return floor((x or 0)*10+0.5)/10 end
local function getAddons()
 local r = {}
 local n = GetNumAddOns and GetNumAddOns() or 0
 for i=1,n do
  local name, title = GetAddOnInfo(i)
  if name and IsAddOnLoaded(i) then
   r[#r+1] = {name=name, title=title or name, memory=safe(GetAddOnMemoryUsage,i) or 0, cpu=safe(GetAddOnCPUUsage,i) or 0}
  end
 end
 return r
end
local function push(s)
 session[#session+1]=s
 if #session>maxSamples then tremove(session,1) end
end
local function top(list,field,count)
 sort(list,function(a,b) return (a[field] or 0)>(b[field] or 0) end)
 local out={}
 for i=1,math.min(count,#list) do
  local a=list[i]
  out[#out+1]=format('%s %s %.1f',a.name,field,a[field] or 0)
 end
 return table.concat(out,'; ')
end
local function sample(dt, fps)
 if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
 if profiling and cpuAPI then pcall(UpdateAddOnCPUUsage) end
 local addons=getAddons()
 local memory, cpu, cpuDelta = 0, 0, 0
 for _,a in ipairs(addons) do
  memory=memory+a.memory
  if profiling and cpuAPI then
   if a.cpu > 0 then cpuObserved = true end
   local old=lastCpu[a.name] or a.cpu
   a.deltaCPU=max(0,a.cpu-old)
   cpuDelta=cpuDelta+a.deltaCPU
   cpu=cpu+a.cpu
   lastCpu[a.name]=a.cpu
  end
 end
 local cpuList={}
 for _,a in ipairs(addons) do cpuList[#cpuList+1]={name=a.name,deltaCPU=a.deltaCPU or 0} end
 local s={time=round(now()-elapsed),fps=round(fps),frameMs=round(dt*1000),memoryKB=round(memory),cpuDeltaMs=round(cpuDelta),topCPU=top(cpuList,'deltaCPU',5),topMemory=top(addons,'memory',5),zone=GetZoneText() or '',inCombat=UnitAffectingCombat('player') and true or false}
 push(s)
 -- Native CPU is unknown until the client supplies positive counters.
 if not (profiling and cpuAPI and cpuObserved) then
  s.cpuDeltaMs=nil
  s.topCPU='UNAVAILABLE: no usable native CPU counters'
 end
 if s.fps<=15 then
  if not episodeStart then episodeStart=s.time; episodeMin=s.fps; episodeMem=s.memoryKB end
  episodeLow=0;episodeMin=math.min(episodeMin,s.fps)
 elseif episodeStart then
  episodeLow=episodeLow+1
  if episodeLow>=2 then
   local e={start=episodeStart,finish=s.time,duration=round(s.time-episodeStart),minFPS=episodeMin,memoryDeltaKB=round(s.memoryKB-episodeMem)}
   episodes[#episodes+1]=e
   db.episodes=db.episodes or {}; db.episodes[#db.episodes+1]=e
   if #db.episodes>80 then table.remove(db.episodes,1) end
   episodeStart=nil;episodeLow=0;episodeMin=999
  end
 end
 if s.frameMs>=spikeThreshold or s.fps<=10 then
  db.spikes[#db.spikes+1]=s
  if #db.spikes>250 then tremove(db.spikes,1) end
  if db.alerts and (not lastSample or now()-lastSample>=5) then
   say(format('Stutter: %.0f FPS, %.0f ms frame; CPU interval %.0f ms. Top: %s',s.fps,s.frameMs,(s.cpuDeltaMs or -1),s.topCPU))
   lastSample=now()
  end
 end
 return s
end
local function escape(s) return tostring(s or ''):gsub('[\r\n\t]',' ') end
local function export()
 local out={'BoneProfiler v1.0.2 TEST | '..date('%Y-%m-%d %H:%M:%S'), 'scriptProfile='..(profiling and '1' or '0')..' ('..cpuStatus()..'; requires full client restart)', 'CPU availability='..(cpuObserved and 'OBSERVED COUNTERS' or 'UNAVAILABLE (not zero)'), 'Time(s)\tFPS\tFrame(ms)\tMemory(KB)\tCPU delta(ms)\tZone\tCombat\tTop CPU\tTop Memory'}
 for _,s in ipairs(session) do out[#out+1]=format('%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s',s.time,s.fps,s.frameMs,s.memoryKB,(s.cpuDeltaMs and tostring(s.cpuDeltaMs) or 'NA'),escape(s.zone),tostring(s.inCombat),escape(s.topCPU),escape(s.topMemory)) end
 out[#out+1]='EPISODES: '..#episodes
 for _,e in ipairs(episodes) do out[#out+1]=format('episode start=%.1fs end=%.1fs duration=%.1fs minFPS=%.1f memoryDeltaKB=%.1f (correlation only)',e.start,e.finish,e.duration,e.minFPS,e.memoryDeltaKB) end
 out[#out+1]='SPIKES (saved between sessions): '..#db.spikes
 for _,s in ipairs(db.spikes) do out[#out+1]=format('spike t=%s fps=%s frame=%sms cpu=%sms top=%s',s.time,s.fps,s.frameMs,s.cpuDeltaMs,escape(s.topCPU)) end
 return table.concat(out,'\n')
end
local ui=CreateFrame('Frame','BoneProfilerWindow',UIParent)
ui:SetWidth(570);ui:SetHeight(415);ui:SetPoint('CENTER');ui:SetFrameStrata('DIALOG');ui:SetMovable(true);ui:EnableMouse(true);ui:RegisterForDrag('LeftButton');ui:SetScript('OnDragStart',function(self) self:StartMoving() end);ui:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
ui:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
local function label(parent,txt,x,y,width,height,size)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal');f:SetPoint('TOPLEFT',x,y);f:SetWidth(width);f:SetHeight(height);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(txt);return f
end
label(ui,'BoneProfiler 1.0.2 TEST — Conquest Reborn',18,-15,490,25)
local close=CreateFrame('Button',nil,ui,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-5)
local stats=label(ui,'Initializing...',20,-52,525,170)
local function button(txt,x,y,w,fn)
 local b=CreateFrame('Button',nil,ui,'UIPanelButtonTemplate');b:SetWidth(w);b:SetHeight(24);b:SetPoint('TOPLEFT',x,y);b:SetText(txt);b:SetScript('OnClick',fn);return b
end
local edit=CreateFrame('EditBox',nil,ui)
edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject('ChatFontNormal');edit:SetWidth(505);edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
local scroll=CreateFrame('ScrollFrame',nil,ui,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',22,-244);scroll:SetPoint('BOTTOMRIGHT',-42,18);scroll:SetScrollChild(edit)
local function refreshExport() edit:SetText(export());edit:HighlightText();edit:SetFocus();scroll:SetVerticalScroll(0) end
button('Copy report (Ctrl+C)',20,-208,160,refreshExport)
button('Clear session',185,-208,110,function() session={} say('Session samples cleared.') end)
button('Clear spikes',300,-208,110,function() db.spikes={} say('Saved spikes cleared.') end)
button('Alerts On/Off',415,-208,130,function() db.alerts=not db.alerts;say('Spike alerts '..(db.alerts and 'ON' or 'OFF')) end)
ui:Hide()
local function showStats()
 local s=session[#session]
 if not s then return end
 local text=format('FPS: %.1f  |  Last sampled frame: %.1f ms  |  Addon memory: %.1f MB\nCPU profiling: %s  |  CPU used during sample: %.1f ms\nSamples: %d  |  Saved spikes: %d  |  Zone: %s\n\nTop CPU since last sample: %s\n\nTop memory: %s',s.fps,s.frameMs,s.memoryKB/1024,(profiling and cpuAPI) and 'ENABLED' or ('UNAVAILABLE: '..cpuStatus()),(s.cpuDeltaMs or -1),#session,#db.spikes,s.zone,s.topCPU,s.topMemory)
 stats:SetText(text)
end
local ticker=0
local maxFrameInInterval=0
A:SetScript('OnUpdate',function(self,dt)
 if not db then return end
 ticker=ticker+dt
 if dt>maxFrameInInterval then maxFrameInInterval=dt end
 if ticker>=samplePeriod then
  local d=maxFrameInInterval;ticker=0;maxFrameInInterval=0
  local fps=GetFramerate and GetFramerate() or (d>0 and 1/d or 0)
  sample(d,fps)
  if ui:IsShown() then showStats() end
 end
end)
A:RegisterEvent('ADDON_LOADED');A:RegisterEvent('PLAYER_LOGIN');A:RegisterEvent('PLAYER_LOGOUT')
A:SetScript('OnEvent',function(self,event,arg)
 if event=='ADDON_LOADED' and arg=='BoneProfiler' then
  BoneProfilerDB=BoneProfilerDB or {};db=BoneProfilerDB;db.spikes=db.spikes or {};db.episodes=db.episodes or {};if db.alerts==nil then db.alerts=false end
 elseif event=='PLAYER_LOGIN' then
  elapsed=now();say('Monitoring started. Open with /bp. CPU: '..cpuStatus()..'.')
 elseif event=='PLAYER_LOGOUT' then
  if db then db.lastSessionSummary={samples=#session,spikes=#db.spikes,date=date('%Y-%m-%d %H:%M')} end
 end
end)
SLASH_BONEPROFILER1='/bp';SLASH_BONEPROFILER2='/boneprofiler'
SlashCmdList.BONEPROFILER=function(msg)
 msg=(msg or ''):lower():gsub('^%s+',''):gsub('%s+$','')
 if msg=='cpu on' then
  SetCVar('scriptProfile','1');say('Requested scriptProfile=1. Actual: '..cpuStatus()..'. If it resets on restart, set SET scriptProfile "1" in WTF/Config.wtf with WoW closed. Restart the entire client.')
 elseif msg=='cpu off' then
  SetCVar('scriptProfile','0');say('Requested scriptProfile=0. Actual: '..cpuStatus()..'. Restart the client.')
 elseif msg=='cpu status' then say('CPU diagnostic: '..cpuStatus()..'; boot-time detected='..tostring(profiling))
 elseif msg=='export' then ui:Show();refreshExport()
 elseif msg=='clear' then session={};db.spikes={};say('Samples and spikes cleared.')
 else if ui:IsShown() then ui:Hide() else ui:Show();showStats() end end
end
