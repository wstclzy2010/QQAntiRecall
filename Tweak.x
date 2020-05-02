// struct RecallModel {
//     id _field1;
//     int _field2;
//     _Bool _field3;
//     struct vector<msg_recall::RecallItem *, std::__1::allocator<msg_recall::RecallItem *>> _field4;
// };

// %hook RecallC2CBaseProcessor
// // - (id)insertRecallMsg:(id)arg1 item:(id)arg2 msgType:(int)arg3
// // {
// // 	NSLog(@"insertRecallMsg的第一个参数为：%@",arg1);
// // 	arg1 = nil;
// // 	return %orig;
// // }
// // - (id)getLocalMessage:(id)arg1
// // {
// // 	return nil;
// // }
// // - (id)solveRecallNotify:(id)arg1 isOnline:(_Bool)arg2 voipNotifyInfo:(id)arg3
// // {

// // 	return %orig(arg1,arg2,nil);
// // }
// - (int)getRecallMsgType:(id)arg1
// {
// 	return 888;
// }

// %end

%hook QQMessageRecallModule
- (void)recvC2CRecallNotify:(const void *)arg1 bufferLen:(int)arg2 
	subcmd:(int)arg3 isOnline:(_Bool)arg4 voipNotifyInfo:(id)arg5{}
%end
