--[[
--This file is part of zenroom
--
--Copyright (C) 2022 Dyne.org foundation
--designed, written and maintained by Alberto Lerda and Denis Roio
--
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU Affero General Public License v3.0
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Affero General Public License for more details.
--
--Along with this program you should have received a copy of the
--GNU Affero General Public License v3.0
--If not, see http://www.gnu.org/licenses/agpl.txt
--
--Last modified by Denis Roio
--on Monday, 21th February 2022
--]]

ETH = require_once'crypto_ethereum'


local function big_wei_to_str_wei(x)
   return x:decimal()
end
local function str_wei_to_big_wei(x)
   return BIG.from_decimal(tostring(x))
end
-- TODO: these conversions are slow
weimult = BIG.new(10):modpower(BIG.new(18), ECP.order())
gweimult = BIG.new(10):modpower(BIG.new(9), ECP.order())
local function str_gwei_to_big_wei(x)
   return ( BIG.from_decimal(tostring(x)) * gweimult )
end
local function big_wei_to_str_gwei(x)
   return ( x / gweimult ):decimal()
end
local function str_eth_to_big_wei(x)
   return ( BIG.from_decimal(tostring(x)) * weimult )
end
local function big_wei_to_str_eth(x)
   return ( ( x / weimult ):decimal() )
end

local function import_eth_tx(obj)
  local res = { }
  res.nonce = ZEN.get(obj, 'nonce', INT.from_decimal, tostring)
  res.gas_price = ZEN.get(obj, 'gas_price', INT.from_decimal, tostring)
  res.gas_limit = ZEN.get(obj, 'gas_limit', INT.from_decimal, tostring)
  res.value = ZEN.get(obj, 'value', INT.from_decimal, tostring)
  if obj.data then
    res.data = ZEN.get(obj, 'data', O.from_hex, tostring)
  else res.data = O.new() end
  if obj.v then res.v = ZEN.get(obj, 'v', O.from_hex) end
  if obj.r then res.r = ZEN.get(obj, 'r', O.from_hex) end
  if obj.s then res.s = ZEN.get(obj, 's', O.from_hex) end
  return res
end
local function export_eth_tx(obj)
  local res = { }
  res.nonce = obj.nonce:decimal()  
  res.gas_price = obj.gas_price:decimal()
  res.gas_limit = obj.gas_limit:decimal()
  res.value = obj.value:decimal()
  if obj.data then res.data = obj.data:octet():hex() end
  if obj.v then res.v = obj.v:octet():hex() end
  if obj.r then res.r = obj.r:octet():hex() end
  if obj.s then res.s = obj.s:octet():hex() end
  return res
end

ZEN.add_schema(
   {
      ethereum_public_key = { import = O.from_hex,
			      export = O.to_hex },
      ethereum_address = { import = O.from_hex,
			   export = O.to_hex },
      ethereum_nonce = function(obj)
	 return ZEN.get(obj, 'result', INT.new, tonumber) end,
      ethereum_transaction = { import = import_eth_tx,
			       export = export_eth_tx },
      signed_ethereum_transaction = { import = O.from_hex,
			              export = O.to_hex },
      gas_price = { import = str_wei_to_big_wei,
		    export = big_wei_to_str_wei },
      gas_limit = { import = str_wei_to_big_wei,
		    export = big_wei_to_str_wei },
      ethereum_value = { import = str_eth_to_big_wei,
			 export = big_wei_to_str_eth },
      gwei_value = { import = str_gwei_to_big_wei,
		     export = big_wei_to_str_gwei },
      wei_value = { import = str_wei_to_big_wei,
		    export = big_wei_to_str_wei }
})

When('create the ethereum key', function()
	initkeys'ethereum'
	ACK.keys.ethereum = ECDH.keygen().private
end)

When('create the ethereum address', function()
	empty'ethereum address'
	local pk = ACK.ethereum_public_key
	if not pk then
	   pk = ECDH.pubgen( havekey'ethereum' )
	end
	ACK.ethereum_address = ETH.address_from_public_key(pk)
	new_codec('ethereum address', { zentype = 'element',
					encoding = 'hex' })
end)

When("create the ethereum transaction of '' to ''",
function(quantity, destaddr)
  empty'ethereum transaction'
  local tx = { }
  tx.gas_price = have'gas price'
  tx.gas_limit = have'gas limit'
  tx.nonce = have'ethereum nonce'
  tx.value = have(quantity)
  tx.to = have(destaddr)
  tx.data = O.new()
  ACK.ethereum_transaction = tx
  new_codec('ethereum transaction', { zentype = 'schema',
  encoding = 'complex'})
end)

When("create the signed ethereum transaction",
function()
  local sk = havekey'ethereum'
  local tx = have'ethereum transaction'
  tx.v = INT.new(1337) -- default local testnet
  ACK.signed_ethereum_transaction =
  ETH.encodeSignedTransaction(sk, tx)
  new_codec('signed ethereum transaction', { zentype = 'schema',
  encoding = 'complex'})
end)

When("create the signed ethereum transaction for chain ''",
function(chainid)
  local sk = havekey'ethereum'
  local tx = have'ethereum transaction'
  local cid = tonumber(chainid)
  if not cid then
    cid = INT.new(O.from_string(tostring(chainid)))
  else cid = INT.new(cid) end
  ZEN.assert(cid, "Invalid chain id: "..chainid)
  tx.v = I.spy(cid)
  tx.r = O.new()
  tx.s = O.new()
  ACK.signed_ethereum_transaction =
  ETH.encodeSignedTransaction(sk, tx)
  new_codec('signed ethereum transaction', { zentype = 'schema',
  encoding = 'complex'})
end)

When("verify the signed ethereum transaction from ''",
function(pubkey)
  local pk = have(pubkey)
  local rawtx = have'signed ethereum transaction'
  local tx = ETH.decodeTransaction(rawtx)
  -- TODO: check decode errors
  ZEN.assert( ETH.verifySignatureTransaction(pk, tx) )
end)
