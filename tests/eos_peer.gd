extends SceneTree
const Peer=preload("res://scripts/network/eos_peer.gd")
const Fixture=preload("res://tests/eos_fixture.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:
 var native=Fixture.Native.new();var sdk=Fixture.SDK.new();var peer=Peer.new()
 check(peer.start(native,sdk,func(_id):return "a".repeat(64))==OK,"Adapter starts without SDK worker")
 for c in range(1,7):check(Peer.logical_channel(c+1,MultiplayerPeer.TRANSFER_MODE_RELIABLE)==c,"Normalize explicit EOSG channel")
 check(Peer.logical_channel(1,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)==0,"Normalize default unreliable channel")
 check(Peer.logical_channel(9,MultiplayerPeer.TRANSFER_MODE_RELIABLE)==-1,"Reject invalid physical channel")
 peer.set_target_peer(2);peer.transfer_channel=4;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 var bytes:=PackedByteArray();bytes.resize(20000);bytes.fill(45)
 check(peer.put_packet(bytes)==OK,"Reliable admission")
 sdk.used=65536;peer.poll()
 check(native.sends.is_empty() and peer.scheduler.queued_bytes==bytes.size(),"Native high-water pauses without advancing offset")
 sdk.used=0;native.error=FAILED;peer.poll()
 check(native.sends.is_empty() and peer.scheduler.streams.values()[0][0].offset==0,"EOSG LimitExceeded/FAILED retries exact fragment")
 native.error=OK;peer.poll()
 check(not native.sends.is_empty() and native.sends[0][3].decode_u32(12)==0,"Retry retains first offset")
 var decoder=Peer.Frames.new();var reconstructed:=PackedByteArray()
 var at:=Time.get_ticks_msec()
 for i in 20:
  peer._pump(at+i*100)
 for send in native.sends:
  check(send[3].size()+6<=1000,"Native payload plus EOSG within budget")
  var data:Dictionary=decoder.receive(2,4,true,send[3],at)
  if data.has("packet"):reconstructed=data.packet
 check(reconstructed==bytes and peer.scheduler.queued_bytes==0,"Reliable fragments reconstruct exact bulk payload")
 # Native bulk reserve protects control even while data sends are paused.
 native.sends.clear();sdk.used=50000
 peer.transfer_channel=4;peer.put_packet(PackedByteArray([1,2,3]))
 peer.transfer_channel=0;peer.put_packet(PackedByteArray([4,5,6]));peer.poll()
 check(native.sends.size()==1 and native.sends[0][1]==0,"Control uses reserved native capacity")
 sdk.used=0;peer.poll()
 # Exact native metadata is normalized before delivery to SceneMultiplayer.
 var message:=PackedByteArray([9,8,7])
 native.packets.append([2,7,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,Peer.Frames.fragment(message,1,0)])
 peer.poll()
 check(peer.get_packet_channel()==6 and peer.get_packet_mode()==MultiplayerPeer.TRANSFER_MODE_UNRELIABLE and peer.get_packet()==message,"Voice channel and mode survive native mapping")
 sdk.result=1;native.sends.clear();peer.transfer_channel=0;peer.put_packet(message);peer.poll()
 check(native.sends.is_empty(),"Failed telemetry fails closed")
 sdk.result=0;peer.poll()
 native.packets.append([2,0,MultiplayerPeer.TRANSFER_MODE_RELIABLE,PackedByteArray([1])]);peer.poll()
 check(2 in native.disconnected and peer.frames.reserved==0 and peer.scheduler.queued_bytes==0,"Malformed peer disconnected with reservations released")
 peer.close();check(peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,"Close clears transport")
 print("EOS_PEER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
