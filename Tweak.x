%hook QQMessageRecallModule
- (void)recvC2CRecallNotify:(const void *)arg1 bufferLen:(int)arg2 
	subcmd:(int)arg3 isOnline:(_Bool)arg4 voipNotifyInfo:(id)arg5
{

}
%end
