 ------------------------------------------------
--  Copyright © 2015-2016   Hugula: Arpg game Engine
--  热更新
--  author pu
--	从Ver_android or Ver_ios 中的cdn_host下载资源包。
-- 	1热更新流程
--	.1 对比本地版本号 streaming 和 persistent 的版本文件。
--	.2 加载文件列表 分别加载streaming 和 persistent的文件列表
--	.3 加载版本文件 对比最新的本地版本号
--	.4 如果不一致下载更新列表。
--	.5 对比 本地文件列表 查找变化的文件。
--	.6 下载变化文件列表。
--	.7 下载完成进入游戏。
--	
--	2注意事项
--	.1 关于文件crc校验 只有add_crc的assetbundle才会进行，并且只有当从persistent目录读取的时候才校验，可以使用UriGroup自己定义校验逻辑
--	.2 CRC_FILELIST 当前版本所有文件的crc信息。CRC_FILELIST.get_item可以获取到某个assetbundle的crc信息
--	.3 BackGroundDownload 是网络加载模块，用于从网络加载URL并保存到persistent目录。
--	.4 ResVersion 版本信息，除了基本版本信息外，还可读取VerExtends_android or VerExtends_ios里面的配置字段，可以用于一些配置。
--	.5 cdn_hosts 用于从网络加载资源的url列表
------------------------------------------------
require("core.loader")
require_bytes = SluaCMD.require_bytes

collectgarbage("setpause", 110)
collectgarbage("setstepmul", 300)
json = require "lib.json"

local Hugula = Hugula
local RuntimePlatform= UnityEngine.RuntimePlatform
local Application= UnityEngine.Application
local WWW = UnityEngine.WWW
local GameObject = UnityEngine.GameObject
local LRequest = Hugula.Loader.LRequest --内存池
local LResLoader = Hugula.Loader.LResLoader

local CODE_VERSION = Hugula.CodeVersion.CODE_VERSION
local APP_VERSION = Hugula.CodeVersion.APP_VERSION
local CUtils= Hugula.Utils.CUtils
local LuaHelper=Hugula.Utils.LuaHelper
local FileHelper=Hugula.Utils.FileHelper
local Common = Hugula.Utils.Common
local PLua = Hugula.PLua
local Download = Hugula.Update.Download 
local CrcCheck = Hugula.Update.CrcCheck
local UriGroup = Hugula.Loader.UriGroup
local Loader = Loader
local require_bytes = require_bytes
local delay = PLua.Delay
local stop_delay = PLua.StopDelay
local Localization = Hugula.Localization --
local HugulaSetting = Hugula.HugulaSetting.instance

ResVersion = {code=1,crc32=0,time=1}

local _progressbar_txt,_progressbar_slider
local FRIST_VIEW = "/Logo"
local VERSION_FILE_NAME = Common.CRC32_VER_FILENAME 
local VERSION_TEMP_FILE_NAME = CUtils.GetAssetName(VERSION_FILE_NAME)..".tmp"
local UPDATED_LIST_NAME = Common.CRC32_FILELIST_NAME 
local UPDATED_TEMP_LIST_NAME =  CUtils.GetAssetName(UPDATED_LIST_NAME)..".tmp"
local DOWANLOAD_TEMP_FILE = "downloaded.tmp"
local update_list_crc_key = CUtils.GetRightFileName(UPDATED_LIST_NAME)
local http_ver_hosts = "http://192.168.100.101/api/ver/get?ver=%s&udid=%s&os=%s&time=%s" --自己构建web服务器通过本地版本判断返回ver.txt /dev|/release|/reivew|...
http_ver_hosts = "http://192.168.100.101/release/"..CUtils.platform.."/v"..CODE_VERSION.."/"..VERSION_FILE_NAME --直接读取版本文件

--local fristView
local local_file,server_file = {},{}
local backgroud_loader
local local_version,server_ver
local main_update = {} 
local MAX_STEP = 6
local DEBUG_UPDATE = false

--- global
CRC_FILELIST = {}
BackGroundDownload = {} --
cdn_hosts = {}

---------------------------local function ----------------
local function check_dev()
	if (Application.platform == RuntimePlatform.OSXEditor or Application.platform == RuntimePlatform.WindowsEditor or Application.platform == RuntimePlatform.WindowsPlayer) then --for test
		-- http_ver_hosts = "http://192.168.100.101/api/ver/get?ver=%s&udid=%s&os=%s&time=%s&force=dev"
		http_ver_hosts = "http://192.168.100.101/dev/"..CUtils.platform.."/v"..CODE_VERSION.."/"..VERSION_FILE_NAME
	end
	print("[LOGIN] http url: " .. http_ver_hosts)
end

check_dev()

local function insert_assetBundle_name(assetbundleName,insert)
	local append = HugulaSetting.appendCrcToFile;
	if append then
		return CUtils.InsertAssetBundleName(assetbundleName,insert)
	else
		return assetbundleName
	end
end
--------------------------the mode of download-----------------
BackGroundDownload.m = 1024
BackGroundDownload.folder = CUtils.GetAssetPath("")
BackGroundDownload.__index = BackGroundDownload

function BackGroundDownload.new()
	local o = {m = BackGroundDownload.m,is_loading = false,folder =BackGroundDownload.folder}
	setmetatable(o,BackGroundDownload)
	return o
end

local BackGroundDownload_mt = {}
BackGroundDownload_mt.__call = function(tb)
	return BackGroundDownload.new()
end

setmetatable(BackGroundDownload,BackGroundDownload_mt)

function BackGroundDownload:get_old_list()
	local temp_file = self.temp_file or DOWANLOAD_TEMP_FILE
	local old_list_context = FileHelper.ReadPersistentFile(temp_file) --读取上次加载未完成列表
	local old_list = {}
	if old_list_context ~= nil then
		-- print("get_old_list="..old_list_context)
		old_list = json:decode(old_list_context)
	end
	self.old_list = old_list
	return  old_list
end

function BackGroundDownload:on_file_down(url,bol,arg)
	-- print(url," is down ",bol)
	if bol == false then
		self.loaded_err = true
		print(url," download error ",arg[1])
	else
		self.loaded_size = self.loaded_size + math.ceil(arg[2])
		-- save loaded file 
		local key = CUtils.GetAssetBundleName(url)
		self.loaded_file[key] = arg
		local context = json:encode(self.loaded_file) 
		local temp_file = self.temp_file or DOWANLOAD_TEMP_FILE
		FileHelper.SavePersistentFile(context,temp_file) --保存加载列表
	end

	if self.one_file_down then self.one_file_down(self,url,bol,arg) end

end

function BackGroundDownload:on_all_file_down(isdown)
	if self.loaded_err then

	else
		local temp_file = self.temp_file or DOWANLOAD_TEMP_FILE
		FileHelper.DeletePersistentFile(temp_file)--删除零时文件
	end
	Download.Dispose()
	self.is_loading = false
	if self.all_file_down then self.all_file_down(self) end

end

function BackGroundDownload:find_change_files(file_list,filter)
	local has_change = false
	local old_list = self:get_old_list()
	-- print(json.encode(old_list))
	
	local urls = {}
	local old_key
	for k,v in pairs(file_list) do 
		for k1,v1 in pairs(v) do
			if filter(k,k1,v1) then
				old_key = insert_assetBundle_name(k1,"_"..v1[1])
				if old_list[old_key] == nil or old_list[old_key][1] ~= v1[1] then
					urls[k1] = v1
					has_change = true
				end
			end
		end
	end
	return urls,has_change
end

function BackGroundDownload:load_files(urls,cdns,one_file_down,all_file_down)
	local download = Download.instance
	self.one_file_down = one_file_down
	self.all_file_down = all_file_down
	local bg_loader = self
	local function on_file_down(...) bg_loader:on_file_down(...)  end
	local function on_all_file_down(...) bg_loader:on_all_file_down(...)  end
	download:Init(cdns,self.max_loading or 2,on_file_down,on_all_file_down)
	self.total_size = 0
	self.loaded_err = false
	self.is_loading = true
	self.loaded_size = 0
	self.loaded_file = {} --加载完成记录
	local file,suffix,crc,file_name
	for k,v in pairs(urls) do
		crc = v[1]
		self.total_size = self.total_size + math.ceil(v[2])
		file_name =  k
		suffix = CUtils.GetSuffix(k)
		if suffix == "" then --如果是目录
			file_name = k..Common.CHECK_ASSETBUNDLE_SUFFIX
		end
		file = insert_assetBundle_name(file_name,"_"..crc) --拼接
		-- print("begin load "..file.." save name "..savefile)
		download:Load(file,k,v)
	end
end

--------------------------end mode of download-----------------

function lua_localization(key,...)--本地化
	local val = Localization.Get(key)
	if ... then 
		val = string.format(val,... )
	end
	return  val
end


function CRC_FILELIST.get_item(key) ----获取所有
	local val = nil
	for k,v in pairs(CRC_FILELIST) do
		if type(v) == "table" then
			val = v[key] 
			if val then return val end
		end
	end
	return val
end

function CRC_FILELIST.get_manual(key) --获取手动更新
	local item = CRC_FILELIST["manual"]
	if item then
		return item[key]
	end
end

function print_time(times)
	print(os.date("%c",times))
end

function run_times(arg)
	CUtils.DebugCastTime(arg or debug.traceback())
end

local function set_resversion(ver) 
	if ver then
		for k,v in pairs(ver) do
			ResVersion[k] = v
		end
	end
end

local function set_resversion_var(ver)
	if ver then
		for k,v in pairs(ver) do
			if not ( k == "code" or k == "crc32" or	k == "version") then
				ResVersion[k] = v
			end
		end
	end
end

local function decode_ver_str(str)
	local ver = json:decode(str)
	return ver
end

-- local function get_ver_uri_group() --ver 列表
-- 	local group = UriGroup()
-- 	local ver_str = CUtils.platform.."/v"..CODE_VERSION.."/"
-- 	for k,v in ipairs(http_ver_hosts) do
-- 		group:Add(v..ver_str)
-- 	end
-- 	return group
-- end

local function get_update_uri_group(hosts, on_www_comp,on_crc_check)
	local group = UriGroup()
	for k,v in pairs(hosts) do
		if on_www_comp == nil then
			group:Add(v)
		else
			group:Add(v,on_www_comp,on_crc_check)
		end
	end
	return group
end

local function set_progress_txt(text,step,per)
 	if _progressbar_txt then _progressbar_txt.text = text end
	if _progressbar_slider and per and step then
		local p = (step+per)/MAX_STEP
	 	_progressbar_slider.value = p 
	end
 	print(text)
end

local function add_file(crc_tb ) --所有文件列表
	local item
	for k,v in pairs(crc_tb) do
		item = CRC_FILELIST[k]
		if item == nil  then item = {} CRC_FILELIST[k] = item end
		for k1,v1 in pairs(v) do	
			item[k1] = v1
			-- print("add_file",k1,v1)
		end		
	end
end

local function add_crc(crc_tb,manual) --加入了crc值的assetbundle会进行校验
	-- local str = ""
	for k,v in pairs(crc_tb) do
		if manual == nil or (manual and k == "manual") then 
			for k1,v1 in pairs(v) do
				CrcCheck.Add(k1,v1[1]) --str = str..string.format("%s=%s,",k1,v1[1])
			end
		end
	end
	-- print("add_crc:"..str)
end

--检测扩展文件
local function check_extends_file(key,v1)
	local manual =CRC_FILELIST.get_manual(key)
	if manual ~= nil then
		local e = FileHelper.PersistentFileExists(key)
		return e
	end	
	return true --
end 

local function enterGame(manifest)

	local function to_begin( ... )
		run_times("enterGame begin.lua ")
		if manifest then
			Loader:unload_dependencies_cache_false(CUtils.GetRightFileName("scene_begin.u3d"))
		end
		CrcCheck.beginCheck = true
		require("begin")
	end

	local function load_manifest( ... )
		set_progress_txt(lua_localization("main_enter_game"),5,1) --)进入游戏......"
		-- print(manifest)
		if manifest then --如果有更新需要刷新
			print("刷新manifest")
	 		Loader:refresh_assetbundle_manifest(to_begin)
		else
			to_begin()
		end
	end

	set_progress_txt(lua_localization("main_refresh_script"),5,0.2) --刷新脚本。"

	cdn_hosts = ResVersion.cdn_host or {}
	delay(load_manifest,0.1)
	
end

local function one_file_down(bg_loader,url,bol,arg)
	-- print(url," is down ",bol)
	if bol == false then
		print(url," download error ",arg[1])
	else
		local m = bg_loader.m
		local loaded_s = math.ceil( bg_loader.loaded_size/m)
		local loaded_t = math.floor( bg_loader.total_size/m)
		set_progress_txt(lua_localization("main_downloading_tips",loaded_s,loaded_t),4,loaded_s/loaded_t)  --string.format("网络资源加载中(消耗流量) %d kb/ %d kb。",loaded_s,loaded_t),4,loaded_s/loaded_t)
	end
end

local function all_file_down(bg_loader)
	-- print("all file is down")
	if bg_loader.loaded_err then
		set_progress_txt(lua_localization("main_download_fail")) --"文件下载失败请重启游戏。")
	else
		set_resversion(server_ver)
		FileHelper.DeletePersistentFile(CUtils.GetRightFileName(UPDATED_LIST_NAME)) --删除旧文件
		FileHelper.DeletePersistentFile(CUtils.GetRightFileName(VERSION_FILE_NAME)) --删除旧文件
		-- print("更新文件列表！")
		FileHelper.ChangePersistentFileName(CUtils.GetRightFileName(UPDATED_TEMP_LIST_NAME),CUtils.GetRightFileName(UPDATED_LIST_NAME))
		-- print("更新版本号！")
		FileHelper.ChangePersistentFileName(CUtils.GetRightFileName(VERSION_TEMP_FILE_NAME),CUtils.GetRightFileName(VERSION_FILE_NAME))
		set_progress_txt(lua_localization("main_download_complete"),4,1) --"更新完毕，进入游戏！"
		local loader_key = "core.loader"
		package.loaded[loader_key] = nil 
		package.preload[loader_key] = nil
		enterGame(true)
		print("all_file_update_down")
	end

end 

main_update.load_server_file_list = function () --版本差异化对比

	local function on_www_comp( req,bytes )
		print("on www comp "..req.assetName)
	 	FileHelper.SavePersistentFile(bytes,CUtils.GetRightFileName(UPDATED_TEMP_LIST_NAME)) --保存server端临时文件
	end

	local function on_server_comp(req)
		set_progress_txt(lua_localization("main_compare_crc_list")) --校验列表对比中。")
		local text_asset = req.data
		server_file = require_bytes(text_asset.bytes)
		-- print(text_asset)
	 	Loader:clear(req.key)
		add_crc(server_file) --加入验证列表

		local function filter_diff(pkey,key,vals)
			local fval = CRC_FILELIST.get_item(key)
			local crc = vals[1]
			local crc_not_equ = true
			if  fval ~= nil then crc_not_equ = fval[1] ~= crc end
			if crc_not_equ and check_extends_file(key,crc) then
				return true
			end
			return  false
		end
		backgroud_loader = BackGroundDownload()
		local urls,change = backgroud_loader:find_change_files(server_file,filter_diff)
		add_file(server_file)
		if change then
			set_progress_txt(lua_localization("main_download_from_webserver"),4,0.01)--开始从服务器加载新的资源。
			backgroud_loader:load_files(urls,server_ver.cdn_host,one_file_down,all_file_down)
		else
			enterGame()
		end
	end

	local function on_server_err(req) 
		print("on_server_err :",req.url)
		enterGame()	
	end

	local function load_server( ... )
		set_progress_txt(lua_localization("main_web_server_crc_list")) --加载服务器校验列表。")
		local crc = tostring(server_ver.crc32)
		local asset_name = CUtils.GetAssetName(UPDATED_LIST_NAME)
		local assetbundle_name = CUtils.GetRightFileName(asset_name..Common.CHECK_ASSETBUNDLE_SUFFIX)
		local file_name =  insert_assetBundle_name(assetbundle_name,"_"..crc)
		print("load web server crc "..file_name)
		local req = LRequest.Get()
		req.relativeUrl = file_name
		req.onCompleteFn = on_server_comp
		req.onEndFn = on_server_err
		req.assetName = asset_name--LuaHelper.GetClassType("System.Byte[]")
		req.uris = get_update_uri_group(server_ver.cdn_host,on_www_comp,nil)
		Loader:get_resource(req)
	end
 
 	load_server()
end


main_update.load_server_verion = function () --加载服务器版本号
	local begin_fun
	 local function on_err( req )
	 	print("load_server_ver on erro"..req.key,req.udKey,req.url,req.assetName,req.assetBundleName)
	 	enterGame()
		set_progress_txt(lua_localization("main_web_server_error"),3,0.0) --"加载服务器版本信息。"
		-- delay(begin_fun,2)
	 end

	 local function on_comp( req )
	 	-- print(req.url,"is onComplete",req.data.Length)
	 	local ver_str = req.data
		print("server var ",ver_str)
	 	server_ver = decode_ver_str(ver_str)
	 	print_time(server_ver.time)
		if server_ver.version and server_ver.version >= local_version.version then --如果服务器版本号>=本地
			set_resversion_var(server_ver)
		end

		 if Application.platform == RuntimePlatform.OSXEditor or Application.platform == RuntimePlatform.WindowsEditor or Application.platform == RuntimePlatform.WindowsPlayer then --for test
			if LResLoader.assetBundleManifest == nil then
				enterGame(true)
			else
				enterGame()
			end
			print("进入测试模式:"..http_ver_hosts)
			return
		end

		FileHelper.SavePersistentFile(ver_str,CUtils.GetRightFileName(VERSION_TEMP_FILE_NAME)) --临时文件

		if CODE_VERSION < server_ver.code then --如果本地代码版本号不一致
  			set_progress_txt(lua_localization("main_download_new_app")) --"请更新app版本！")
			Application.OpenURL(server_ver.update_url)
	 	elseif server_ver.version > local_version.version then --服务器版本号大于等于当前版本号 --&& server_ver.crc32 ~= local_version.crc32
	 		main_update.load_server_file_list()
	 	else
	 		enterGame()
	 	end
	 end

	begin_fun = function()
		set_progress_txt(lua_localization("main_web_server_ver"),3,0.5) --"加载服务器版本信息。"
		local udid = UnityEngine.SystemInfo.deviceUniqueIdentifier --
		local ver_url = string.format(http_ver_hosts,APP_VERSION,udid,CUtils.platform,os.time()) -- ResVersion http://gw-warx.dev.tapenjoy.com/api/ver/get?ver=1.0.1&udid=111111&os=ios&time=1491533172
		print(ver_url)
		Loader:get_resource(ver_url,nil,String,on_comp,on_err,nil,nil)--
	end

	begin_fun()
end

main_update.load_local_file_list = function () --加载本地列表

	local step = {}
	step.next_step=function( ... )
		main_update.load_server_verion()
	end

	step.on_persistent_comp=function( req )
		local text_asset = req.data
		local_file = require_bytes(text_asset.bytes)
		print(" on_persistent_file_list",text_asset)
		add_crc(local_file)
		add_file(local_file)
		Loader:clear(req.key)
		step.next_step()
	end

	step.on_persistent_error=function( req )
		print("本地没有校验文件"..req.url)
		step.next_step()
	end

	step.load_persistent_file=function ( ... )
		if CrcCheck.ContainsKey(update_list_crc_key) then
			set_progress_txt(lua_localization("main_local_check")) --"读取本地校验文件。")
			local crc = CrcCheck.GetCrc(update_list_crc_key)
			-- print("persistent update file list"..tostring(crc))
			local group = UriGroup()
			group:Add(CUtils.GetRealPersistentDataPath(),true)
			Loader:get_resource(UPDATED_LIST_NAME,nil,nil,step.on_persistent_comp,step.on_persistent_error,nil,group)
		else
			-- print("本地没有校验文件")
			step.next_step()
		end
	end

    --
    local step1 = {}
    step1.on_streaming_comp = function( req )
    	local text_asset = req.data
    	print("on_streaming_filelist",text_asset)
		local s_crc32_file = require_bytes(text_asset.bytes)
		add_file(s_crc32_file)
		add_crc(s_crc32_file,true) --add manual
		Loader:clear(req.key)
		step.load_persistent_file()
    end
    step1.on_streaming_error = function( req )
		print("<color=#ffff00>streaming crc32_filelist does't exist use (Hugula/BUild For Bublish) build</color>")
    	step.load_persistent_file()
    end
    step1.load_streaming_file = function( ... )
		local uri = CUtils.GetRealStreamingAssetsPath()
		local url = CUtils.PathCombine(uri,UPDATED_LIST_NAME)
		print("load_streaming_file  "..url)
		Loader:get_resource(url,nil,nil,step1.on_streaming_comp,step1.on_streaming_error)
    end

    step1.load_streaming_file()
end


main_update.compare_local_version = function () --对比本地版本号
	local step = {}
	step.key = CUtils.GetRightFileName(UPDATED_LIST_NAME)
	step.on_persistent_comp=function ( req )
		local ver_str = req.data
		-- print("local persistent ver ",ver_str)
		local ver_json = decode_ver_str(ver_str) 
		print_time(ver_json.time)
		step.persistent_version = ver_json
		CrcCheck.Add(update_list_crc_key,tonumber(ver_json.crc32))--本地验证列表的crc验证
		-- print("persistent ver crc",update_list_crc_key,"=",ver_json.crc32)
		step.compare()
	end

	step.on_persistent_error=function ( req )
		step.persistent_error = true
		print("local verion persistent erro ",req.key)
		step.compare()
	end

	step.compare=function(  )
		if step.persistent_error == true and  step.streaming_version ~= nil then
			-- print("没有缓存版本文件！")
			local_version = step.streaming_version
			set_resversion(local_version)
			main_update.load_local_file_list()
		elseif step.persistent_version ~= nil and step.streaming_version ~= nil then
			if step.persistent_version.version >= step.streaming_version.version then
				print("直接进入。%s > %s",step.persistent_version.version,step.streaming_version.version)
				local_version = step.persistent_version
				set_resversion(local_version)
				main_update.load_local_file_list()			
			else
				set_progress_txt(lua_localization("main_clear_cache")) --清理旧的缓存。")
				print("清理缓存。"..CUtils.GetRealPersistentDataPath())
				FileHelper.DeletePersistentDirectoryFiles(nil)
				CrcCheck.Clear() --清除校验列表
				package.loaded["core.loader"] = nil 
				package.preload["core.loader"] = nil
				print("delete lua core.loader")
				local_version = step.streaming_version --当前版本
				set_resversion(local_version)
				main_update.load_local_file_list()
			end
		end
	end

	step.on_streaming_comp=function ( req )
		local ver_str = req.data 
		-- print("local streaming ver ",ver_str)
		local ver_json = decode_ver_str(ver_str)
		print_time(ver_json.time)
		step.streaming_version = ver_json
		step.compare()
	end

	step.on_streaming_error=function ( req ) --never happen
		print("<color=#ffff00>streaming ver.txt does't exist use (Hugula/BUild For Bublish) build</color>")
		step.streaming_version = {code=0,crc32=0,time=os.time(),version=APP_VERSION}
		step.compare()
	end

	step.load_persistent=function(  )
		print("加载本地缓存版本信息。")
		local uri = CUtils.GetRealPersistentDataPath()
		local url = CUtils.PathCombine(uri,VERSION_FILE_NAME)
		print(url)
  		Loader:get_resource(url,nil,String,step.on_persistent_comp,step.on_persistent_error,nil)
	end

	step.load_streaming=function(  )
		print("加载本地版本信息。") --
		local uri = CUtils.GetRealStreamingAssetsPath()
		local url = CUtils.PathCombine(uri,VERSION_FILE_NAME)
		print(url)
    	Loader:get_resource(url,nil,String,step.on_streaming_comp,step.on_streaming_error,nil)
	end

  	set_progress_txt(lua_localization("main_compare_local_ver"),2,0.2) --"对比本地版本信息。"
	step.load_streaming()
	step.load_persistent()
end

local function init_step1()
	-- print(Hugula.Utils.CUtils.GetRealPersistentDataPath())
	-- print(Hugula.Utils.CUtils.GetRealStreamingAssetsPath())
	-- print(UnityEngine.Application.version,Application.bundleIdentifier)
	local ui_logo = LuaHelper.Find(FRIST_VIEW)
	_progressbar_txt = ui_logo:GetComponentInChildren(UnityEngine.UI.Text,true)
	_progressbar_slider = ui_logo:GetComponentInChildren(UnityEngine.UI.Slider,true)
	set_progress_txt(lua_localization("main_init"),1,1)

	main_update.compare_local_version()

end

run_times("main.lua ")


init_step1()
