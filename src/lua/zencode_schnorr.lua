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
--]]

local SCH = require'crypto_schnorr_signature'

local function schnorr_public_key_f(obj)
   local res = O.from_hex(obj)
   ZEN.assert(
      SCH.pubcheck(res),
      'Schnorr public key is not valid'
   )
   return res
end

local function schnorr_signature_f(obj)
   local res = O.from_hex(obj)
   ZEN.assert(
      SCH.sigcheck(res),
      'Schnorr signature is not valid'
   )
   return res
end

-- check various locations to find the public key
--  Given I have a 's' from 't'            --> ACK.s[t] 
local function _pubkey_compat(_key)
   local pubkey = ACK[_key]
   if not pubkey then
      local pubkey_arr = ACK.schnorr_public_key
      if luatype(pubkey_arr) == 'table' then
	 pubkey = pubkey_arr[_key]
      else
	 pubkey = pubkey_arr
      end
      ZEN.assert(
	 pubkey,
	 'Public key not found for: ' .. _key
      )
   end
   return pubkey
end


ZEN.add_schema(
   {
      schnorr_public_key = { import = schnorr_public_key_f,
			     export = O.to_hex },
      schnorr_signature = { import = schnorr_signature_f,
			    export = O.to_hex },
   }
)


-- generate the private key
When('create the schnorr key',
     function()
	initkeys'schnorr'
	ACK.keys.schnorr = SCH.keygen()
     end
)

-- generate the public key
When('create the schnorr public key',
     function()
	empty'schnorr public key'
	local sk = havekey'schnorr'
	ACK.schnorr_public_key = SCH.pubgen(sk)
	new_codec('schnorr public key', { zentype = 'element',
					  encoding = 'hex'})
     end
)

When("create the schnorr public key with secret key ''",
     function(sec)
	local sk = have(sec)
	initkeys'schnorr'
	ACK.keys.schnorr = sk
	empty'schnorr public key'
	ACK.schnorr_public_key = SCH.pubgen(sk)
	new_codec('schnorr public key', { zentype = 'element',
					  encoding = 'hex'})
     end
)

-- generate the sign for a msg and verify
When("create the schnorr signature of ''",
     function(doc)
	local sk = havekey'schnorr'
	local obj = have(doc)
	empty'schnorr signature'
	ACK.schnorr_signature = SCH.sign(sk, obj)
	new_codec('schnorr signature', { zentype = 'element',
					 encoding = 'hex'})
     end
)

IfWhen("verify the '' has a schnorr signature in '' by ''",
       function(msg, sig, by)
	  local pk = _pubkey_compat(by, 'schnorr')
	  local m = have(msg)
	  local s = have(sig)
	  ZEN.assert(
	     SCH.verify(pk, m, s),
	     'The schnorr signature by '..by..' is not authentic'
	  )
       end
)