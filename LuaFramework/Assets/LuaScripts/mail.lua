local MailManager = class("Mail")

local Flag = {
	Read 		= bit(0),		--�Ѷ�
	Recv 		= bit(1),		--��������ȡ
	Delete 		= bit(2),		--��ɾ��
}

function MailManager:Clear()
	self.units = {}
end

function MailManager:ctor()
	self.units = {}		--�ʼ�����
	
	--ע��������Ϣ
	registerMsgHandler("sendMaill", "sendMaill")
	registerMsgHandler("recvMailItems", "recvMailItems")
end

function MailManager:getMail(uuid)
	for k, v in pairs(self.units) do
		if v.uuid == uuid then
			return v
		end
	end
	return nil
end

function MailManager:addMail(mail)
	local old = self:getMail(mail.uuid)
	if old then
		old.flag = mail.flag
		old.index = mail.index
		return
	else
		table.insert(self.units, mail)
	end
	
	-- table.sort(self.units, function(left,right) 
		-- if left.time <= right.time then return false end
		-- return true
	-- end)
	-- print(self.units)
end

--��ȡ�ʼ�
function MailManager:readMail(uuid)
	if bit_and(self.units[uuid].flag, Flag.Read) ~= 0 then return end
	
	local sp = SpObject()
	sp:Insert("uuid", uuid)
	sendNetMsg("readMail", sp)		
end
--[[
function testrecvMailItems(cmd)
	local arr = string.split(cmd, " ")
	g_Mails:recvMailItems(tonumber(arr[2]))
end
--]]
--��ȡ����
function MailManager:recvMailItems(index)
	index = index + 1
	if bit_and(self.units[index].flag, Flag.Recv) ~= 0 then return end		--δ��ȡ
	if Table_Get_N(self.units[index].items) == 0 then return end			--�����Ǹ����ʼ�
	
	local sp = SpObject()
	sp:Insert("uuid", self.units[index].uuid)
	sendNetMsg("recvMailItems", sp)	
end



---------------------------------------
--������Ϣ
--�յ��ʼ�����
function onHandleRequest_sendMaill( sp )
	 Util.Log("onHandleRequest_sendMaill")
     Util.DumpObject(sp)
     
     local dict = sp:getTable("mailsList")
     if not dict then return end
	 local index_ = 0
	 dict = Api.SortDic(dict)
     for p in Slua.iter(dict) do
     	local uuid = p.value:getString("uuid")
     	local mail = {
			index = index_,
			uuid =  p.value:getString("uuid"),
			title =  p.value:getString("title"),		--����
			content =  p.value:getString("content"),	--����
			sender =  p.value:getString("sender"),		--�����ߣ�system��
			items =  {},								--����
			flag = p.value:getInt("flag"),				--�ʼ���ʶ
			time = p.value:getInt("time"),				--����ʱ��
		}
		index_ = index_ + 1
		local items =  p.value:getString("items")
		local arr = string.split(items, ",")
		print(arr)
		for i=1, #arr, 2 do
			mail.items[tonumber(arr[i])] = tonumber(arr[i+1])
		end
		g_Mails:addMail(mail)
		MessageManager.HandleMessage(MsgType.UpdateMail, mail)
     end
     --
end

--��ȡ�����ظ�
function onHandleResponse_recvMailItems( sp )
 	Util.Log("onHandleResponse_recvMailItems")
    Util.DumpObject(sp)
     
    local errorCode = sp:getInt("errorCode")
	local uuid = sp:getString("uuid")				
	local dict = sp:getTable("items")
	local items = {}
	if dict then		--��õĵ���[data id]=[����]
		for p in Slua.iter(dict) do
			items[p.value:getInt("x")] = p.value:getInt("y")
		end
	end
	--
	if errorCode ~= 0 then
		MessageBox.Instance:OpenText("error code : " .. tostring(errorCode), Color.red, 1, MessageBoxPos.Middle)
		return
	end
	
	if table.size(items) > 0 then
		UIManager.Instance:OpenPanel("OpenBoxPanel", false, items)
	else
		MessageBox.Instance:OpenText("��ȡ�ɹ�!", Color.cyan, 1, MessageBoxPos.Middle)
	end
	
	local info = nil
	for k, v in pairs(g_Mails.units) do
		v.index = k - 1
		if v.uuid == uuid then
			info = v
		end
	end
	MessageManager.HandleMessage(MsgType.ReceiveMailItem, info)
end

return MailManager.new()

