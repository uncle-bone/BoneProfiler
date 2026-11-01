-- BoneProfiler 1.0.6 TEST, WoW 3.3.5a / Lua 5.1
local F = CreateFrame('Frame','BoneProfilerFrame',UIParent)
local fmt, floor, max, min, sort = string.format, math.floor, math.max, math.min, table.sort
local clock = GetTime
local db, samples, episodes = nil, {}, {}
local boot, login, tick, worst, frames, lowCount = clock(), nil, 0, 0, 0, 0
local cpuBoot = GetCVar and tostring(GetCVar('scriptProfile')) or 'unknown'
local cpuAPIs = type(GetAddOnCPUUsage)=='function' and type(UpdateAddOnCPUUsage)=='function'
local cpuRequested = cpuBoot=='1'
local cpuState = cpuRequested and cpuAPIs and 'pending' or 'fallback'
local cpuProbeCount = 0
local lastCPU, lastMEM, totals = {}, {}, {}
local cpuTimer, memTimer, lastAlert = 0, 0, -999
local lastCPUText, lastMemText, lastMemDelta = 'unavailable', 'not sampled', 'not sampled'
local lastCpuDelta, addonMemory, active = nil, 0, nil
local verbose = false
-- Some custom 3.3.5a clients expose a focus query; stock 3.3.5a may not.
-- Never infer actual focus solely from low FPS or slow OnUpdate calls.
local focusEvents, focusLast, focusSource = {}, nil, 'unknown'
local focusOverride = 'auto'
local focusAPIName = nil
-- Heuristic is not a focus API: report possible throttling separately.
local fpsHints, fpsHintState, fpsHintSince = {}, 'unclassified', 0
local manualMarkers = {}
local function cap(name, fallback)
 local v=GetCVar and tonumber(GetCVar(name))
 return v and v>0 and v or fallback
end
local function recordHint(t, fps)
 local fg,bg=cap('maxFPS',62),cap('maxFPSBk',30)
 local nextState='unclassified'
 if fg-bg>=15 then
  if fps>=bg-2 and fps<=bg+2 then nextState='possible background cap'
  elseif fps>=bg+8 then nextState='above background cap'
  elseif fps<bg-2 then nextState='below background cap (possible lag)'
  else nextState='between caps' end
 end
 if nextState~=fpsHintState then
  local prior=fpsHintState
  local elapsed=t-fpsHintSince
  fpsHints[#fpsHints+1]={t=t,fps=fps,from=prior,to=nextState,priorDuration=elapsed,fg=fg,bg=bg}
  if #fpsHints>150 then table.remove(fpsHints,1) end
  fpsHintState,fpsHintSince=nextState,t
 end
 return nextState
end

local function readFocus()
 if focusOverride~='auto' then return focusOverride, 'manual annotation' end
 local probes={'IsWindowFocused','IsGameWindowFocused','GetWindowFocus'}
 for _,name in ipairs(probes) do
  local fn=_G[name]
  if type(fn)=='function' then
   local ok,value=pcall(fn)
   if ok and type(value)=='boolean' then focusAPIName=name;return value and 'foreground' or 'background',name end
   if ok and type(value)=='number' and (value==0 or value==1) then focusAPIName=name;return value==1 and 'foreground' or 'background',name end
  end
 end
 return 'unknown','no compatible focus API'
end
local function focusAt(t)
 local state,source=readFocus()
 if state~=focusLast or source~=focusSource then
  focusEvents[#focusEvents+1]={t=t,state=state,source=source}
  if #focusEvents>150 then table.remove(focusEvents,1) end
  focusLast,focusSource=state,source
 end
 return state,source
end
local function say(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff55bbffBoneProfiler:|r '..s) end end
local function safe(fn, ...) if type(fn)~='function' then return nil end local ok,r=pcall(fn,...); if ok then return r end end
local function round(n) return floor((n or 0)*10+0.5)/10 end
local function bootStatus()
 local current = GetCVar and tostring(GetCVar('scriptProfile')) or 'unreadable'
 return 'startup CVar='..cpuBoot..', current CVar='..current..', CPU APIs='..(cpuAPIs and 'present' or 'missing')..', requested='..tostring(cpuRequested)..', counters='..cpuState
end
local function loaded()
 local found={}; local n=safe(GetNumAddOns) or 0
 for i=1,n do
  local name=safe(GetAddOnInfo,i)
  if name and safe(IsAddOnLoaded,i) then found[#found+1]={name=name,index=i} end
 end
 return found
end
local function ranking(items,key,count,unit)
 sort(items,function(a,b) return (a[key] or 0)>(b[key] or 0) end)
 local out={}
 for i=1,min(count,#items) do out[#out+1]=fmt('%s %.1f%s',items[i].name,items[i][key] or 0,unit or '') end
 return #out>0 and table.concat(out,', ') or 'none'
end
local function collectCPU()
 if not cpuRequested then return end
 if not cpuAPIs then cpuState='fallback'; lastCPUText='native API missing; fallback active'; return end
 if not pcall(UpdateAddOnCPUUsage) then cpuState='fallback'; lastCPUText='native API error; fallback active'; return end
 local ranks, total, positive={},0,false
 for _,a in ipairs(loaded()) do
  local v=safe(GetAddOnCPUUsage,a.index)
  if type(v)=='number' then
   if v>0 then positive=true end
   if lastCPU[a.name] then
    local d=max(0,v-lastCPU[a.name]); total=total+d
    ranks[#ranks+1]={name=a.name,ms=d}
    totals[a.name]=(totals[a.name] or 0)+d
   end
   lastCPU[a.name]=v
  end
 end
 if positive then cpuState='working' else cpuProbeCount=cpuProbeCount+1; cpuState='fallback' end
 lastCpuDelta=(cpuState=='working') and round(total) or nil
 lastCPUText=cpuState=='working' and ranking(ranks,'ms',8,'ms') or 'native CPU unavailable; FPS/memory fallback active'
end
local function setCPU(enabled)
 cpuRequested=enabled
 if enabled then
  if type(SetCVar)=='function' then pcall(SetCVar,'scriptProfile','1') end
  cpuState='pending'; cpuProbeCount=0;lastCPU={};lastCpuDelta=nil
  collectCPU()
  say('CPU diagnostics ON immediately. '..bootStatus()..'. Native CPU may require client startup; FPS/memory fallback remains active.')
 else
  if type(SetCVar)=='function' then pcall(SetCVar,'scriptProfile','0') end
  cpuState='fallback';lastCpuDelta=nil;lastCPUText='native CPU off; FPS/memory fallback active'
  say('Native CPU sampling OFF immediately. FPS/memory monitoring continues. '..bootStatus())
 end
end
local function collectMemory()
 if type(UpdateAddOnMemoryUsage)~='function' or type(GetAddOnMemoryUsage)~='function' then lastMemText='unsupported';return end
 if not pcall(UpdateAddOnMemoryUsage) then lastMemText='API error';return end
 local ranks, changes, total={}, {}, 0
 for _,a in ipairs(loaded()) do
  local kb=safe(GetAddOnMemoryUsage,a.index)
  if type(kb)=='number' then
   total=total+kb
   ranks[#ranks+1]={name=a.name,kb=kb}
   if lastMEM[a.name] then changes[#changes+1]={name=a.name,kb=kb-lastMEM[a.name]} end
   lastMEM[a.name]=kb
  end
 end
 addonMemory=total
 lastMemText=ranking(ranks,'kb',6,'KB')
 lastMemDelta=ranking(changes,'kb',6,'KB')
end
local function push(a,record,limit)
 a[#a+1]=record
 if #a>limit then table.remove(a,1) end
end
local function relative() return round(clock()-(login or boot)) end
local function context()
 return (safe(GetZoneText) or '?'), (safe(UnitAffectingCombat,'player') and true or false)
end
local function beginEpisode(s)
 active={focusStart=s.focus,focusSource=s.focusSource,focusTransitions=0,start=s.t,firstFPS=s.fps,minFPS=s.fps,worstMs=s.frameMs,samples=0,baseline=s.baseline,zone=s.zone,cpuStart=lastCPUText,memStart=addonMemory,memChanges={},cpuChanges={}}
 if db.alerts and clock()-lastAlert>=15 then say(fmt('Slowdown began at +%.1fs, %.1f FPS. Recording episode.',s.t,s.fps));lastAlert=clock() end
end
local function finishEpisode(t,reason)
 if not active then return end
 active.finish=t;active.duration=round(t-active.start);active.reason=reason or 'recovered'
 active.memEnd=addonMemory;active.memDeltaKB=round(addonMemory-active.memStart)
 active.cpuEnd=lastCPUText;active.cpuState=cpuState;active.focusEnd=focusLast
 push(episodes,active,40)
 db.episodes=db.episodes or {};push(db.episodes,active,80)
 if db.alerts then say(fmt('Episode +%.1f to +%.1fs (%.1fs), minimum %.1f FPS.',active.start,t,active.duration,active.minFPS)) end
 active=nil
end
local function sample()
 local period=tick
 local fps=safe(GetFramerate) or (period>0 and frames/period or 0)
 local zone,combat=context()
 local focus,focusMethod=focusAt(relative())
 local fpsHint=recordHint(relative(),round(fps))
 if active and focus~=active.lastFocus then active.focusTransitions=active.focusTransitions+1;active.lastFocus=focus end
 local s={t=relative(),fps=round(fps),frameMs=round(worst*1000),zone=zone,combat=combat,memKB=round(addonMemory),cpuMs=lastCpuDelta,topCPU=lastCPUText,topMemory=lastMemText,memGrowth=lastMemDelta,baseline=0,frames=frames,focus=focus,focusSource=focusMethod,fpsHint=fpsHint}
 -- Baseline is computed from recent healthy observations; never from low-FPS samples.
 local healthy={};for i=max(1,#samples-30),#samples do local q=samples[i];if q and q.fps>=25 then healthy[#healthy+1]=q.fps end end
 local sum=0;for _,v in ipairs(healthy) do sum=sum+v end
 s.baseline=#healthy>0 and round(sum/#healthy) or 0
 push(samples,s,900)
 local bad=s.fps<=15 or (s.baseline>=35 and s.fps<s.baseline*0.4)
 if bad then lowCount=lowCount+1 else lowCount=0 end
 if bad and not active then beginEpisode(s) end
 if active then
  active.samples=active.samples+1
  active.minFPS=min(active.minFPS,s.fps);active.worstMs=max(active.worstMs,s.frameMs)
  if not bad and s.fps>=25 then active.recovered=(active.recovered or 0)+1 else active.recovered=0 end
  if active.recovered>=2 then finishEpisode(s.t,'recovered') end
 end
 if s.frameMs>=100 then
  db.spikes=db.spikes or {};push(db.spikes,{time=s.t,fps=s.fps,frameMs=s.frameMs,zone=zone},250)
 end
 tick,worst,frames=0,0,0
end
local function report(detailed)
 local out={'BoneProfiler v1.0.6 TEST | '..date('%Y-%m-%d %H:%M:%S'),bootStatus(),
 'CPU unavailable means NOT MEASURED, never zero CPU. CPU=working only after positive native counters observed.',
 'Client='..tostring(safe(GetBuildInfo) or '?')..' | monitoring='..tostring(db.monitor~=false),
 'Frame samples='..#samples..' | completed episodes='..#episodes..' | saved historical episodes='..#(db.episodes or {}),
 'Native CPU evidence='..lastCPUText,'Memory ranking='..lastMemText,'Memory interval changes='..lastMemDelta,
 'Analysis: timing and memory changes are correlation, NOT per-addon CPU attribution.',
 'Focus detection='..(focusAPIName or 'unsupported')..'; current='..tostring(focusLast)..' ('..focusSource..'). Unknown is NOT background.',
 'Focus timeline events='..#focusEvents,
 'FPS caps: foreground='..tostring(cap('maxFPS',62))..' background='..tostring(cap('maxFPSBk',30))..'; FPS-based hints are NOT confirmed window focus.',
 'FPS cap transitions='..#fpsHints..'; manual test markers='..#manualMarkers}
 local list={};for _,e in ipairs(episodes) do list[#list+1]=e end
 if active then list[#list+1]=active end
 for i,e in ipairs(list) do
  out[#out+1]=fmt('EPISODE %d: +%.1fs to +%s; duration=%s; minimumFPS=%.1f; worstFrame=%.1fms; baselineFPS=%.1f; addonMemDelta=%sKB; CPU=%s; zone=%s',i,e.start,e.finish and fmt('%.1fs',e.finish) or 'ONGOING',e.duration or '?',e.minFPS,e.worstMs,e.baseline or 0,e.memDeltaKB or '?',e.cpuState or cpuState,e.zone or '?')
  out[#out+1]='  Focus: start='..tostring(e.focusStart)..' end='..tostring(e.focusEnd or focusLast)..' transitions='..tostring(e.focusTransitions or 0)..' source='..tostring(e.focusSource)
  out[#out+1]='  CPU at start: '..tostring(e.cpuStart)..' | most recent CPU: '..tostring(e.cpuEnd or lastCPUText)
 end
 if detailed then
  out[#out+1]='FPS cap hint transitions (not proof of Alt+Tab):'
  for _,e in ipairs(fpsHints) do out[#out+1]=fmt('+%.1fs %.1f FPS: %s -> %s (previous %.1fs; caps %s/%s)',e.t,e.fps,e.from,e.to,e.priorDuration,e.fg,e.bg) end
  out[#out+1]='Manual markers:'
  for _,e in ipairs(manualMarkers) do out[#out+1]=fmt('+%.1fs %s',e.t,e.label) end
  out[#out+1]='Focus transitions (not keyboard input):'
  for _,e in ipairs(focusEvents) do out[#out+1]=fmt('+%.1fs %s [%s]',e.t,e.state,e.source) end
  out[#out+1]='Timeline: seconds | FPS | worst frame ms | addon KB | native CPU interval ms (NA if disabled) | top CPU | top memory | focus | focus source'
  for _,s in ipairs(samples) do
   out[#out+1]=fmt('%.1f | %.1f | %.1f | %.1f | %s | %s | %s | %s | %s | %s',s.t,s.fps,s.frameMs,s.memKB,s.cpuMs and tostring(s.cpuMs) or 'NA',s.topCPU,s.topMemory,s.focus or 'unknown',s.focusSource or '?',s.fpsHint or 'unclassified')
  end
 end
 return table.concat(out,'\n')
end
local ui=CreateFrame('Frame','BoneProfilerWindow',UIParent)
ui:SetSize(650,460);ui:SetPoint('CENTER');ui:SetFrameStrata('DIALOG');ui:SetMovable(true);ui:SetResizable(true);ui:SetMinResize(550,350);ui:SetMaxResize(1000,800);ui:EnableMouse(true);ui:RegisterForDrag('LeftButton')
ui:SetScript('OnDragStart',function(self) self:StartMoving() end);ui:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
ui:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
local function label(text,x,y)
 local f=ui:CreateFontString(nil,'OVERLAY','GameFontNormal');f:SetPoint('TOPLEFT',x,y);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(text);return f
end
label('BoneProfiler v1.0.6 TEST | Conquest Reborn',18,-16)
local close=CreateFrame('Button',nil,ui,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-5)
local status=label('Waiting for first sample...',20,-56);status:SetWidth(590);status:SetHeight(125)
local scroll=CreateFrame('ScrollFrame',nil,ui,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',22,-235);scroll:SetPoint('BOTTOMRIGHT',-42,18)
local edit=CreateFrame('EditBox',nil,ui);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject('ChatFontNormal');edit:SetWidth(560);edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);scroll:SetScrollChild(edit)
local function export(detailed) edit:SetText(report(detailed));edit:HighlightText();edit:SetFocus();scroll:SetVerticalScroll(0) end
local function button(text,x,y,w,callback)
 local b=CreateFrame('Button',nil,ui,'UIPanelButtonTemplate');b:SetSize(w,24);b:SetPoint('TOPLEFT',x,y);b:SetText(text);b:SetScript('OnClick',callback);return b
end
local monitorButton, alertsButton
local function updateButtons()
 if not db then return end
 monitorButton:SetText(db.monitor==false and 'Monitor: OFF' or 'Monitor: ON')
 alertsButton:SetText(db.alerts and 'Alerts: ON' or 'Alerts: OFF')
 local function tint(button,enabled)
  local fs=button:GetFontString()
  if fs then if enabled then fs:SetTextColor(0.25,1,0.35) else fs:SetTextColor(1,0.35,0.35) end end
 end
 tint(monitorButton,db.monitor~=false)
 tint(alertsButton,db.alerts)
end
button('Compact report',20,-170,115,function() export(false);say('Compact report ready. Press Ctrl+C to copy.') end)
button('Detailed report',139,-170,115,function() export(true);say('Detailed report ready. Press Ctrl+C to copy.') end)
monitorButton=button('Monitor: ON',258,-170,118,function()
 db.monitor=(db.monitor==false)
 updateButtons();say('Performance monitoring '..(db.monitor and 'ENABLED' or 'DISABLED'))
end)
button('Clear samples',380,-170,116,function() samples={};episodes={};active=nil;say('Current session samples and episodes cleared.') end)
alertsButton=button('Alerts: OFF',500,-170,116,function()
 db.alerts=not db.alerts
 updateButtons();say('Performance alerts '..(db.alerts and 'ENABLED' or 'DISABLED'))
end)
button('Focus status',20,-201,118,function()
 local state,source=focusAt(relative());say('Window focus: '..state..' ('..source..')')
end)
button('Clear history',142,-201,126,function() db.spikes={};db.episodes={};say('Saved spike and episode history cleared.') end)
button('Diagnostics help',282,-201,142,function()
 say('FPS, frame-time, memory, episodes and focus monitoring run without native CPU profiling.')
 say('Native CPU measurements are experimental: /bp cpu status, /bp cpu on, /bp cpu off.')
end)
local grip=CreateFrame('Button',nil,ui);grip:SetSize(18,18);grip:SetPoint('BOTTOMRIGHT',-8,8);grip:EnableMouse(true);grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up');grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight');grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down');grip:SetScript('OnMouseDown',function() ui:StartSizing('BOTTOMRIGHT') end);grip:SetScript('OnMouseUp',function() ui:StopMovingOrSizing();edit:SetWidth(max(420,ui:GetWidth()-90));status:SetWidth(max(420,ui:GetWidth()-60)) end)
ui:Hide()
local function refresh()
 local s=samples[#samples];if not s then return end
 status:SetText(fmt('Focus %s (%s) | FPS %.1f | worst frame %.1f ms | login +%.1fs | addon memory %.1f MB\nCPU %s | %s\nSlowdown: %s | episodes: %d | samples: %d\nTop CPU: %s\nMemory changes: %s',s.focus or 'unknown',s.focusSource or '?',s.fps,s.frameMs,s.t,s.memKB/1024,cpuState,cpuBoot,active and ('ACTIVE from +'..active.start..'s') or 'none',#episodes,#samples,lastCPUText,lastMemDelta))
end
F:SetScript('OnUpdate',function(self,dt)
 if not db or db.monitor==false then return end
 tick=tick+dt;frames=frames+1;worst=max(worst,dt)
 cpuTimer=cpuTimer+dt;memTimer=memTimer+dt
 if cpuTimer>=3 then cpuTimer=0;collectCPU() end
 if memTimer>=5 then memTimer=0;collectMemory() end
 if tick>=1 then sample();if ui:IsShown() then refresh() end end
end)
F:RegisterEvent('ADDON_LOADED');F:RegisterEvent('PLAYER_LOGIN');F:RegisterEvent('PLAYER_LOGOUT')
F:SetScript('OnEvent',function(self,event,arg)
 if event=='ADDON_LOADED' and arg=='BoneProfiler' then
  BoneProfilerDB=BoneProfilerDB or {};db=BoneProfilerDB
  db.spikes=db.spikes or {};db.episodes=db.episodes or {}
  if db.alerts==nil then db.alerts=false end
  updateButtons()
 elseif event=='PLAYER_LOGIN' then
  login=clock();say('Monitoring started. Alerts '..(db.alerts and 'ON' or 'OFF')..'; monitoring '..(db.monitor==false and 'OFF' or 'ON')..'. /bp opens reports.')
 elseif event=='PLAYER_LOGOUT' and db then
  if active then finishEpisode(relative(),'logout') end
  db.lastSessionSummary={samples=#samples,episodes=#episodes,date=date('%Y-%m-%d %H:%M')}
 end
end)
SLASH_BONEPROFILER1='/bp';SLASH_BONEPROFILER2='/boneprofiler'
SlashCmdList.BONEPROFILER=function(msg)
 msg=(msg or ''):lower():gsub('^%s+',''):gsub('%s+$','')
 if msg=='cpu status' then say(bootStatus())
 elseif msg=='cpu on' then setCPU(true)
 elseif msg=='cpu off' then setCPU(false)
 elseif msg=='export' or msg=='export full' then ui:Show();export(msg=='export full')
 elseif msg=='clear' then samples={};episodes={};active=nil;db.spikes={};db.episodes={};say('History cleared')
 elseif msg=='mark' or msg:match('^mark ') then local label=msg:match('^mark%s*(.*)') or '';if label=='' then label='manual marker' end;manualMarkers[#manualMarkers+1]={t=relative(),label=label};say('Marked +'..fmt('%.1fs',relative())..': '..label)
 elseif msg=='focus status' then local state,source=focusAt(relative());say('Focus: '..state..' ('..source..'). Unknown means the client provides no supported focus API.')
 elseif msg=='focus auto' or msg=='focus foreground' or msg=='focus background' then focusOverride=msg:match('focus (.+)');local state,source=focusAt(relative());say('Focus annotation: '..state..' ('..source..')')
 elseif msg=='alerts on' or msg=='alerts off' then db.alerts=msg=='alerts on';updateButtons();say('Performance alerts '..(db.alerts and 'ENABLED' or 'DISABLED'))
 elseif msg=='monitor on' or msg=='monitor off' then db.monitor=msg=='monitor on';updateButtons();say('Performance monitoring '..(db.monitor and 'ENABLED' or 'DISABLED'))
 elseif msg=='status' then say('Monitoring '..(db.monitor==false and 'OFF' or 'ON')..'; alerts '..(db.alerts and 'ON' or 'OFF')..'; focus '..tostring(focusLast)..'; native CPU '..cpuState)
 else if ui:IsShown() then ui:Hide() else ui:Show();refresh() end end
end

