local CoolDown = class("CoolDown")

function update_CoolDown_data(uid, val)
	g_CoolDown:update(uid, val)
end

CoolDownSysType =
{
        ResetCardPower          		= 0,    --Ӣ����������
        RefreshShopCard                 = 1,    --�����̵�ˢ��
        
        TimeLimitSale                   = 1001, --��ʱ�ػ���Ʒ
}

function CoolDown:Clear()
	self.units = {}
end

--����uid���accountId, atype
function CoolDown.calcNameType(uid)
	local t = string.split(uid, '$')
	return t[1], tonumber(t[2])
end

--���ϵͳCD uid
function CoolDown.calcSysUid(atype)
        return 'system' .. '$' .. atype
end

--������CD uid
function CoolDown:calcAccountUid(atype)
        return Account.accountId .. '$' .. atype
end

--����key���uid
function CoolDown.calcUid(name, atype)
        return name .. '$' .. atype
end


function CoolDown:ctor()
	self.units = {}
end


function CoolDown.create(uid, val)
         return {uid=uid, value=val}
end

--���ݸ��·���
function CoolDown:update(uid, val)
	
	if self.units[uid] then
		self.units[uid].value = val
	else
		self.units[uid] = self.create(uid, val)
	end
	local name, atype = CoolDown.calcNameType(uid)
	--���� atype ���ж��Ǻ���CD���ݸ�����
	
	if atype == CoolDownSysType.RefreshShopCard then
		local value = self:getSysValue(atype)
		MessageManager.HandleMessage(MsgType.UpdateShopCd, value)
	elseif atype == CoolDownSysType.TimeLimitSale then
		local value = self:getAccountValue(atype)
		MessageManager.HandleMessage(MsgType.RefreshGift, value)
	end
end

--���ϵͳCDֵ
function CoolDown:getSysValue(atype)
	local uid = self.calcUid('system', atype)
	if self.units[uid] then
		print("uid",self.units)
		return self.units[uid].value
	end
	return 0
end

--������CDֵ
function CoolDown:getAccountValue(atype)
	local uid = self.calcUid(Account.accountId, atype)
	if self.units[uid] then
		return self.units[uid].value
	end
	return 0
end

----------------------------------------------------------------------------------------------------------------------

function CoolDown:RefreshShopCd()
	local uid = self.calcSysUid(CoolDownSysType.RefreshShopCard)
	SystemLogic.Instance:UpdateCDData(uid)
end

return CoolDown.new()

