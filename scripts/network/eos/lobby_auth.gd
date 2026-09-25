extends RefCounted
## SceneMultiplayer admission, before hello/roster/RPC traffic is allowed.
const TIMEOUT:=12.0
var api:SceneMultiplayer
var hosting:=false
var password:=""
var locked:=false
var salt:=PackedByteArray()
var key:=PackedByteArray()
var challenges:Dictionary={}
var rejected_peers:Dictionary={}
signal rejected(peer:int)
signal failed
static func valid_password(value:String)->bool:
 return value.length()<=64 and value.to_utf8_buffer().size()<=256
static func derive(value:String,random_salt:PackedByteArray)->PackedByteArray:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
 hash.update("UBS lobby password v1".to_utf8_buffer());hash.update(random_salt)
 if not value.is_empty():hash.update(value.to_utf8_buffer())
 return hash.finish()
static func proof(secret:PackedByteArray,challenge:PackedByteArray)->PackedByteArray:
 return Crypto.new().hmac_digest(HashingContext.HASH_SHA256,secret,challenge)
func install(multiplayer_api:SceneMultiplayer,is_host:bool,value:String)->void:
 reset()
 api=multiplayer_api;hosting=is_host;password=value;locked=not value.is_empty()
 if hosting:
  salt=Crypto.new().generate_random_bytes(16);key=derive(password,salt);password=""
 api.auth_callback=receive;api.auth_timeout=TIMEOUT
 api.peer_authenticating.connect(begin)
 api.peer_authentication_failed.connect(authentication_failed)
func reset()->void:
 if api!=null:
  if api.peer_authenticating.is_connected(begin):api.peer_authenticating.disconnect(begin)
  if api.peer_authentication_failed.is_connected(authentication_failed):api.peer_authentication_failed.disconnect(authentication_failed)
  api.auth_callback=Callable()
 api=null;password="";key.clear();salt.clear();challenges.clear();rejected_peers.clear()
func begin(id:int)->void:
 if not hosting:return
 rejected_peers.erase(id)
 var nonce:=Crypto.new().generate_random_bytes(32)
 challenges[id]=nonce
 var data:=PackedByteArray([0,1 if locked else 0]);data.append_array(salt);data.append_array(nonce)
 api.send_auth(id,data)
func reject(id:int)->void:
 if rejected_peers.has(id):return
 if rejected_peers.size()>=64:rejected_peers.erase(rejected_peers.keys()[0])
 rejected_peers[id]=true;rejected.emit(id)
func deny(id:int)->void:
 challenges.erase(id);reject(id)
 if api!=null:api.disconnect_peer(id)
func receive(id:int,data:PackedByteArray)->void:
 if api==null:return
 if hosting:
  if data.size()!=33 or data[0]!=1 or not challenges.has(id):deny(id);return
  var expected:=proof(key,challenges[id]);challenges.erase(id)
  if not Crypto.new().constant_time_compare(expected,data.slice(1)):deny(id);return
  api.send_auth(id,PackedByteArray([2]));api.complete_auth(id)
 else:
  if id!=1:return
  if data.size()==50 and data[0]==0 and data[1] in [0,1] and not challenges.has(1):
   challenges[1]=true
   var supplied:=password if data[1]==1 else ""
   var response:=PackedByteArray([1]);response.append_array(proof(derive(supplied,data.slice(2,18)),data.slice(18)))
   api.send_auth(1,response)
  elif data==PackedByteArray([2]) and challenges.has(1):
   challenges.clear();password="";api.complete_auth(1)
  else:deny(id)
func authentication_failed(id:int)->void:
 challenges.erase(id)
 if hosting:reject(id)
 else:password="";failed.emit()
