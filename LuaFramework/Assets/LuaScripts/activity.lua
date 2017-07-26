local Activity = class("Activity")

function update_activity_data(uid, val, time)
	g_Activity:update(uid, val, time)
end

ActivitySysType =
{
		--RefreshShopCard               = 0,    --�̳ǿ���ˢ������
		ShopCardId1                     = 0,    --����̳ǵ���id1
	  ShopCardId2                     = 1,    --����̳ǵ���id2
		ShopCardId3                     = 2,    --����̳ǵ���id3
		
   	BuyShopCard1                    = 1001, --�̳ǹ�����1����
   	BuyShopCard2                    = 1002, --�̳ǹ�����2����
   	BuyShopCard3                    = 1003, --�̳ǹ�����3����
   	PvpTimes												= 2001, --pvp�μӳ���
   	PvpWinTimes											= 2002, --pvpʤ������
   	RefreshExplore									= 3001, --ˢ��̽������
       
}

function Activity:Clear()
	self.units = {}
end


--����uid���accountId, atype
function Activity.calcNameType(uid)
	local t = string.split(uid, '$')
	return t[1], tonumber(t[2])
end


--���ϵͳ�uid
function Activity.calcSysUid(atype)
        return 'system' .. '$' .. atype
end

--�����һ uid
function Activity:calcAccountUid(atype)
        return Account.accountId .. '$' .. atype
end

--����key���uid
function Activity.calcUid(name, atype)
        return name .. '$' .. atype
end


function Activity:ctor()
	self.units = {}
end


function Activity.create(uid, val, time)
         return {uid=uid,  value=val, time = time}
end

--���ݸ��·���
function Activity:update(uid, val, time)
	-- Util.Log("Activity:update")
	-- print("uid = "..uid)
	-- print("val = "..val)
	-- print("time = "..time)
	if self.units[uid] then
		self.units[uid].value = val		--����
		self.units[uid].time = time		--ʣ��ʱ��
	else
		self.units[uid] = self.create(uid, val, time)
	end
	
	local name, atype = Activity.calcNameType(uid)
	
	if atype == ActivitySysType.ShopCardId1 then
		local t = { }
		local value = val
		t.index = atype
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopCard, t)
	elseif atype == ActivitySysType.ShopCardId2 then
		local t = { }
		local value = val
		t.index = atype
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopCard, t)
	elseif atype == ActivitySysType.ShopCardId3 then
		local t = { }
		local value = val
		t.index = atype
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopCard, t)
	elseif atype == ActivitySysType.BuyShopCard1 then
		local index = string.sub(tostring(atype), string.len(tostring(atype))) - 1
		local value = val
		local t = { }
		t.index = index
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopRemainingCardNum, t)
	elseif atype == ActivitySysType.BuyShopCard2 then
		local index = string.sub(tostring(atype), string.len(tostring(atype))) - 1
		local value = val
		local t = { }
		t.index = index
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopRemainingCardNum, t)
	elseif atype == ActivitySysType.BuyShopCard3 then
		local index = string.sub(tostring(atype), string.len(tostring(atype))) - 1
		local value = val
		local t = { }
		t.index = index
		t.value = value
		MessageManager.HandleMessage(MsgType.RefreshShopRemainingCardNum, t)
	elseif atype == ActivitySysType.PvpTimes then
		MessageManager.HandleMessage(MsgType.PvpTimes, val)
	elseif atype == ActivitySysType.PvpWinTimes	then
		MessageManager.HandleMessage(MsgType.PvpWinTimes, val)
	elseif atype == ActivitySysType.RefreshExplore then
		MessageManager.HandleMessage(MsgType.RefreshExplore, val)
	end
end

--���ϵͳ�ֵ
function Activity:getSysValue(atype)
	local uid = self.calcUid('system', atype)
	if self.units[uid] then
		return self.units[uid].value
	end
	return 0
end

--�����һֵ
function Activity:getAccountValue(atype)
	local uid = self.calcUid(Account.accountId, atype)
	if self.units[uid] then
		return self.units[uid].value
	end
	return 0
end

return Activity.new()

