#!/usr/bin/env zsh

[[ -r test ]] || {
	print "Run from base directory: ./test/$0"
	return 1
}
zen=($*)
# echo "using: $zen"
curve="goldilocks"
secret="This is the secret message that is sent among people."
ppl=(zora vuk mira darko)

tmp=`mktemp -d`
# echo "tempdir: $tmp"

generate() {
	for p in $ppl; do
		cat <<EOF | $zen > $tmp/$p-keys.json
keys = ecdh.new('$curve')
keys:keygen()
keypair = json.encode({
      public=keys:public():hex(),
      private=keys:private():hex()})
print(keypair)
EOF
		cat <<EOF | $zen -k $tmp/$p-keys.json > $tmp/$p-envelop.json
keys = json.decode(KEYS)
envelop = json.encode({
    message="$secret",
    pubkey=keys['public']})
print(envelop)
EOF
	done
}

encrypt() {
    from=$1
    to=$2
    cat <<EOF | $zen -k $tmp/$from-keys.json -a $tmp/$to-envelop.json \
					 > $tmp/from-$from-to-$to-cryptomsg.json 
keys = json.decode(KEYS)
data = json.decode(DATA)
recipient = ecdh.new('$curve')
recipient:public(octet.hex(data['pubkey']))
sender = ecdh.new('$curve')
sender:private(octet.hex(keys['private']))
k = sender:session(recipient)
iv = sender:random(16)
enc,tag = sender:encrypt(k,octet.string(data['message']),iv,octet.string('header'))
print(json.encode({
	iv=iv:hex(),
	tag=tag:hex(),
    encmsg=enc:hex(),
    pubkey=keys['public']}))
EOF
}

decrypt() {
	from=$1
	to=$2
	cat <<EOF | $zen -k $tmp/$to-keys.json -a $tmp/from-$from-to-$to-cryptomsg.json
keys = json.decode(KEYS)
data = json.decode(DATA)
recipient = ecdh.new('$curve')
recipient:private(octet.hex(keys['private']))
sender = ecdh.new('$curve')
sender:public(octet.hex(data['pubkey']))
k = recipient:session(sender)
iv = octet.hex(data['iv'])
tag = octet.hex(data['tag'])
dec = recipient:decrypt(k,octet.hex(data['encmsg']),iv,octet.string('header'), tag)
print(dec:string())
EOF
}

print - "== Running integration tests for asymmetric crypto messaging"
generate

for p in $ppl; do
	for pp in $ppl; do
		[[ "$p" = "$pp" ]] && continue
		from=$p
		to=$pp
		print "ENCRYPT $from -> $to"
		encrypt $p $pp
		cat $tmp/from-$from-to-$to-cryptomsg.json | json_pp
	done
done

for p in $ppl; do
	for pp in $ppl; do
		[[ "$p" = "$pp" ]] && continue
		from=$pp
		to=$p
		print "DECRYPT $from -> $to"
		res=`decrypt $from $to`
		if [[ "$secret" != "$res" ]]; then
			print - "ERROR in integration ecdh test: $tmp"			
			print - "INPUT keys:"
			cat $tmp/$to-keys.json | json_pp
			print - "INPUT data:"
			cat $tmp/from-$from-to-$to-cryptomsg.json | json_pp
			# print $secret | xxd
			print - "OUTPUT string: ${#res} bytes"
			print $res | xxd
			print - "envelope from ${from}:"
			cat $tmp/$pp-envelop.json
			print - "recipient-keys to ${to}:"
			cat $tmp/$p-keys.json
			print - "cryptomsg:"
			cat $tmp/from-$from-to-$to-cryptomsg.json
			print - "==="
			return 1
		else
			# print "OK integration luazend test PASSED: from $p to $pp"
		fi
	done
done

# just in case
[[ "$tmp" != "/" ]] && rm -rf "$tmp"
print - "== All tests passed OK"
return 0
