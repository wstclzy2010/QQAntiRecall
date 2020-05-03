# QQAntiRecall
iOS版QQ防撤回

---
## 切入点
要实现一个功能，最重要是找到切入点，从哪里入手，是先要确定的。对于防撤回来说，撤回成功后会有个提示
![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200502-160557.png)

根据这个提示，去ida中搜索string，通过交叉引用找到有哪些方法或者函数调用了这个string，然后对这些方法下断点，观察是哪一个或者哪一些方法触发了断点，一步步找到调用的关系。
### 静态分析
把砸过壳的可执行程序拖入ida，等待ida解析完成（因为QQ程序很大，消耗了很长的时间。），需要特别注意的是QQ的主程序是在静态库文件下的
```
xxxxxxx/QQ.app/Frameworks/QQMainProject.framework/QQMainProject
```
在ida中开启string window
![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200502-161210.png)

右键string window窗口中的内容，点击setup开启对Unicode的支持

![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200501-215330.png)

![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200501-215259.png) 

这样就可以搜索中文了，搜索“对方撤回”后，双击对应地址，点击X就可以查看交叉引用

![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200501-223826.png)

可以看到一共只有两个方法，那就比较方便了，就对这两个方法下断点。拿到ida中的文件偏移，加上ASLR地址就可以对方法下断点。

### 动态调试
这里启动lldb，先利用image list -o -f查看主程序的ASLR地址
```
(lldb) image list -o -f
[  0] 0x0000000000dd0000 /var/containers/Bundle/Application/199B45A3-9F43-4154-9338-0F59EDAF6FF5/QQ.app/QQ(0x0000000100dd0000)
[  1] 0x000000010100c000 /Library/Caches/cy-yEWays.dylib(0x000000010100c000)
[  2] 0x0000000100e14000 /Library/MobileSubstrate/MobileSubstrate.dylib(0x0000000100e14000)
[  3] 0x00000001010cc000 /private/var/containers/Bundle/Application/199B45A3-9F43-4154-9338-0F59EDAF6FF5/QQ.app/Frameworks/QQMainProject.framework/QQMainProject(0x00000001010cc000)
```
还是要注意这里的主程序是QQMainProject而不是第一行的QQ，得到ASLR地址后对前面找到的两个方法下断点。然后发送一条消息，撤回试试，可以看到第二个断点成功被触发，也就是撤回消息的提示用到的方法为：- (id)getRecallMessageContent:(struct RecallItem *)arg1

```
(lldb) br s -a '0x1010cc000+0x1EAC7A8'
Breakpoint 1: where = QQMainProject`___lldb_unnamed_symbol208484$$QQMainProject, address = 0x0000000102f787a8
(lldb) br s -a '0x1010cc000+0x4D0A858'
Breakpoint 2: where = QQMainProject`___lldb_unnamed_symbol424456$$QQMainProject, address = 0x0000000105dd6858
(lldb) c
Process 3776 resuming
Process 3776 stopped
* thread #10, name = 'DefaultNet', stop reason = breakpoint 2.1
    frame #0: 0x0000000105dd6858 QQMainProject`___lldb_unnamed_symbol424456$$QQMainProject
QQMainProject`___lldb_unnamed_symbol424456$$QQMainProject:
->  0x105dd6858 <+0>:  stp    x20, x19, [sp, #-0x20]!
    0x105dd685c <+4>:  stp    x29, x30, [sp, #0x10]
    0x105dd6860 <+8>:  add    x29, sp, #0x10            ; =0x10 
    0x105dd6864 <+12>: mov    x19, x2
    0x105dd6868 <+16>: bl     0x101101764               ; ___lldb_unnamed_symbol949$$QQMainProject
    0x105dd686c <+20>: adrp   x8, 10181
    0x105dd6870 <+24>: ldr    x1, [x8, #0x970]
    0x105dd6874 <+28>: bl     0x106a22700               ; symbol stub for: objc_msgSend
Target 0: (QQ) stopped.
(lldb) po $x0
<RecallFriendProcessor: 0x2829618a0>
(lldb) x/s $x1
0x108fa53b9: "getRecallMessageContent:"
(lldb) po $x2
10753840768
```

可以看到当前对象的类是RecallFriendProcessor，它实际上是RecallC2CBaseProcessor的子类，当前被调用的方法是getRecallMessageContent。先记着，再
查看调用栈

```
(lldb) bt
* thread #10, name = 'DefaultNet', stop reason = breakpoint 2.1
  * frame #0: 0x0000000105dd6858 QQMainProject`___lldb_unnamed_symbol424456$$QQMainProject
    frame #1: 0x0000000105dd64d0 QQMainProject`___lldb_unnamed_symbol424454$$QQMainProject + 1816
    frame #2: 0x0000000102b870f4 QQMainProject`___lldb_unnamed_symbol190007$$QQMainProject + 88
    frame #3: 0x0000000102b86c08 QQMainProject`___lldb_unnamed_symbol189999$$QQMainProject + 48
    frame #4: 0x000000010a5dd87c TlibDy`___lldb_unnamed_symbol119$$TlibDy + 416
    frame #5: 0x000000010a5dd6ac TlibDy`___lldb_unnamed_symbol118$$TlibDy + 68
    frame #6: 0x000000010a5dd4f4 TlibDy`___lldb_unnamed_symbol117$$TlibDy + 60
    frame #7: 0x0000000200456690 Foundation`__NSThreadPerformPerform + 336
    frame #8: 0x00000001ff960f1c CoreFoundation`__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 24
    frame #9: 0x00000001ff960e9c CoreFoundation`__CFRunLoopDoSource0 + 88
    frame #10: 0x00000001ff960784 CoreFoundation`__CFRunLoopDoSources0 + 176
    frame #11: 0x00000001ff95b6c0 CoreFoundation`__CFRunLoopRun + 1004
    frame #12: 0x00000001ff95afb4 CoreFoundation`CFRunLoopRunSpecific + 436
    frame #13: 0x00000001ff95bd10 CoreFoundation`CFRunLoopRun + 80
    frame #14: 0x00000002004564a0 Foundation`__NSThread__start__ + 984
    frame #15: 0x00000001ff5ed2c0 libsystem_pthread.dylib`_pthread_body + 128
    frame #16: 0x00000001ff5ed220 libsystem_pthread.dylib`_pthread_start + 44
    frame #17: 0x00000001ff5f0cdc libsystem_pthread.dylib`thread_start + 4
```

栈是先进的在下面，后进的在上面。在getRecallMessageContent方法被执行的前面还有三个方法，它显示为lldb_unnamed_symbol，这是因为没有恢复符号的原因，并不影响。依次通过内存地址减去ASLR地址可以得到方法在ida中的偏移地址，比如0x105dd64d0-0x1010cc000=0x4D0A4D0，在ida中点击G，前往地址4D0A4D0，就可以看到lldb_unnamed_symbol424454方法的名称。得到两个OC方法和一个C函数,调用顺序是下往上：
```
4D0A4D0      -[RecallC2CBaseProcessor solveRecallNotify:isOnline:voipNo
1ABB0F4      -[QQMessageRecallModule handleRecallNotify:isOnline:voipNotifyInfo:]
1ABAC08      sub_1ABABD8
```

先看一下这个C函数

![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200502-154237.png)

可以看到交叉引用，这个C函数实际上是 -[QQMessageRecallModule handleC2CRecallNotify: bufferLen: subcmd: isOnline: voipNotifyInfo:]方法的内部调用的，看下该函数的实现

![Alt text](https://github.com/wstclzy2010/QQAntiRecall/blob/master/image/QQ20200502-170055.png)

它里面调用的方法只有一个，就是 - (void)recvC2CRecallNotify:(const void *)arg1 bufferLen:(int)arg2 subcmd:(int)arg3 isOnline:(_Bool)arg4 voipNotifyInfo:(id)arg5，它也是QQMessageRecallModule类当中的方法。



通过完全相同的步骤，又依次得到了讨论组和群聊的撤回方法，和上述好友间撤回只有名称的不同，并且都在QQMessageRecallModule类当中：
```
- (void)recvDiscussRecallNotify:(char *)arg1 bufferLen:(unsigned int)arg2 isOnline:(_Bool)arg3 voipNotifyInfo:(id)arg4;
- (void)recvGroupRecallNotify:(char *)arg1 bufferLen:(unsigned int)arg2 isOnline:(_Bool)arg3 voipNotifyInfo:(id)arg4;
```

## HOOK测试
从上面的分析可以知道，sub_1ABABD8函数是第一个被调用的，其中的方法- (void)recvC2CRecallNotify:(const void *)arg1 bufferLen:(int)arg2 subcmd:(int)arg3 isOnline:(_Bool)arg4 voipNotifyInfo:(id)arg5就是第一个被调用的用于消息撤回提示的OC方法，我们可以尝试hook一下这个方法
```
%hook QQMessageRecallModule
//好友间
- (void)recvC2CRecallNotify:(const void *)arg1 bufferLen:(int)arg2 
	subcmd:(int)arg3 isOnline:(_Bool)arg4 voipNotifyInfo:(id)arg5
{

}
//讨论组
- (void)recvDiscussRecallNotify:(char *)arg1 bufferLen:(unsigned int)arg2 
	isOnline:(_Bool)arg3 voipNotifyInfo:(id)arg4
{

}
//群聊
- (void)recvGroupRecallNotify:(char *)arg1 bufferLen:(unsigned int)arg2
	isOnline:(_Bool)arg3 voipNotifyInfo:(id)arg4
{

}
%end
```
这里让该方法的实现为空，达到不执行的效果，发一条消息撤回一下，确实有效，消息仍然保留

## 存在的问题
由于这里的方法太粗暴，撤回后没有任何提示，也就是区分不了被撤回的消息和普通消息直接的区别。后续需要进一步的调试分析，比如为被撤回的消息改变颜色，或者在其下方增加拦截成功之类的提示
