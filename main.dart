import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiRoot = String.fromEnvironment('STURK_API_URL', defaultValue: 'https://YOUR-DOMAIN/api.php');
const bg = Color(0xFF0E1621), panel = Color(0xFF17212B), panel2 = Color(0xFF202B36);
const accent = Color(0xFF5288C1), accentBright = Color(0xFF6AB2F2);
const textMain = Color(0xFFF0F2F5), textMuted = Color(0xFF9BA8B8);

void main() => runApp(const SturkApp());

class SturkApp extends StatelessWidget {
  const SturkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sturk', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: accentBright, surface: panel),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: textMain, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: panel2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        hintStyle: const TextStyle(color: textMuted),
      ),
    ),
    home: const AuthGate(),
  );
}

class SturkApi {
  static String token = '';
  static Future<Map<String,dynamic>> call(String action, [Map<String,dynamic> data = {}]) async {
    final uri = Uri.parse(apiRoot);
    final response = await http.post(uri,
      headers: {'Content-Type':'application/json', if (token.isNotEmpty) 'Authorization':'Bearer $token'},
      body: jsonEncode({'action':action, ...data}));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Сервер вернул HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String,dynamic>) throw Exception('Некорректный ответ API');
    if (decoded['success'] == false || decoded['error'] != null) {
      throw Exception((decoded['message'] ?? decoded['error'] ?? 'Ошибка API').toString());
    }
    return decoded;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  Map<String,dynamic>? user;
  bool busy = false;
  final phone = TextEditingController(), password = TextEditingController();
  String? error;
  Future<void> login() async {
    setState(() {busy=true; error=null;});
    try {
      final data=await SturkApi.call('login', {'phone':phone.text.trim(),'password':password.text});
      SturkApi.token=(data['token'] ?? data['data']?['token'] ?? '').toString();
      final u=data['user'] ?? data['data']?['user'];
      if (SturkApi.token.isEmpty || u is! Map) throw Exception('API не вернул токен пользователя');
      setState(()=>user=Map<String,dynamic>.from(u));
    } catch(e) { setState(()=>error=e.toString().replaceFirst('Exception: ','')); }
    finally { if(mounted) setState(()=>busy=false); }
  }
  @override Widget build(BuildContext context) {
    if(user!=null) return ChatsScreen(user:user!, onLogout:()=>setState(()=>user=null));
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding:const EdgeInsets.all(24), child:
      Container(padding:const EdgeInsets.all(24), decoration:BoxDecoration(color:panel, borderRadius:BorderRadius.circular(26), border:Border.all(color:Colors.white.withOpacity(.06)), boxShadow:[BoxShadow(color:accent.withOpacity(.10),blurRadius:35)]),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch, children:[
          const Icon(Icons.forum_rounded,color:accentBright,size:48),
          const SizedBox(height:12), const Text('Sturk',textAlign:TextAlign.center,style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,letterSpacing:.5)),
          const SizedBox(height:5), const Text('Твой мессенджер',textAlign:TextAlign.center,style:TextStyle(color:textMuted)),
          const SizedBox(height:28),
          TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Номер телефона',prefixIcon:Icon(Icons.phone_rounded))),
          const SizedBox(height:12),
          TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Пароль',prefixIcon:Icon(Icons.lock_rounded)),onSubmitted:(_)=>login()),
          if(error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.redAccent))),
          const SizedBox(height:18),
          FilledButton(onPressed:busy?null:login,style:FilledButton.styleFrom(backgroundColor:accent, padding:const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
            child:busy?const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('Войти',style:TextStyle(fontWeight:FontWeight.bold))),
          const SizedBox(height:12), const Text('Адрес API задаётся при сборке через STURK_API_URL.',style:TextStyle(color:textMuted,fontSize:11),textAlign:TextAlign.center)
        ])
      )
    ))));
  }
}

class ChatsScreen extends StatefulWidget {
  final Map<String,dynamic> user; final VoidCallback onLogout;
  const ChatsScreen({super.key,required this.user,required this.onLogout});
  @override State<ChatsScreen> createState()=>_ChatsScreenState();
}
class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String,dynamic>> chats=[]; bool loading=true; String? error; Timer? timer;
  @override void initState(){super.initState(); refresh(); timer=Timer.periodic(const Duration(seconds:5),(_)=>refresh(silent:true));}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> refresh({bool silent=false}) async {
    try {
      final d=await SturkApi.call('get_chats');
      final list=(d['chats'] ?? d['data']?['chats'] ?? []) as List;
      if(mounted) setState(()=>chats=list.map((e)=>Map<String,dynamic>.from(e)).toList());
    } catch(e){if(mounted&&!silent)setState(()=>error=e.toString());}
    finally {if(mounted)setState(()=>loading=false);}
  }
  String chatTitle(Map<String,dynamic> c)=> (c['title']??c['name']??'Чат').toString();
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:accent.withOpacity(.2),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.forum_rounded,color:accentBright,size:20)),const SizedBox(width:10),const Text('Sturk',style:TextStyle(fontWeight:FontWeight.w800))]),
      actions:[IconButton(tooltip:'Обновить',onPressed:()=>refresh(),icon:const Icon(Icons.sync_rounded)),PopupMenuButton<String>(onSelected:(v){if(v=='logout'){SturkApi.token='';widget.onLogout();}},itemBuilder:(_)=>const [PopupMenuItem(value:'logout',child:Text('Выйти'))])]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):RefreshIndicator(onRefresh:refresh,child:ListView.separated(padding:const EdgeInsets.all(12),itemCount:chats.length,separatorBuilder:(_,__)=>const Divider(height:1,color:Color(0x182FFFFFF)),itemBuilder:(context,i){
      final c=chats[i]; final title=chatTitle(c); final preview=(c['last_message']??'Начните общение').toString();
      return Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ConversationScreen(chat:c,title:title,myUserId:int.tryParse('${widget.user['id']}')??0))),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),child:Row(children:[
        CircleAvatar(radius:25,backgroundColor:accent.withOpacity(.2),child:Text(title.isNotEmpty?title[0].toUpperCase():'S',style:const TextStyle(color:accentBright,fontWeight:FontWeight.bold))),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:textMain,fontWeight:FontWeight.w700,fontSize:15)),const SizedBox(height:4),Text(preview,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:textMuted,fontSize:13))])),
        const Icon(Icons.chevron_right_rounded,color:textMuted)
      ])))));
    })),
  );
}

class ConversationScreen extends StatefulWidget {
  final Map<String,dynamic> chat; final String title; final int myUserId;
  const ConversationScreen({super.key,required this.chat,required this.title,required this.myUserId});
  @override State<ConversationScreen> createState()=>_ConversationScreenState();
}
class _ConversationScreenState extends State<ConversationScreen>{
  List<Map<String,dynamic>> messages=[]; bool loading=true,sending=false; String? error;
  final input=TextEditingController(); final scroll=ScrollController(); Timer? timer; int requestSerial=0;
  int get chatId=>int.tryParse('${widget.chat['id']}')??0;
  @override void initState(){super.initState();load();timer=Timer.periodic(const Duration(seconds:3),(_)=>load(silent:true));}
  @override void dispose(){timer?.cancel();input.dispose();scroll.dispose();super.dispose();}
  Future<void> load({bool silent=false}) async {
    final serial=++requestSerial;
    try {
      final d=await SturkApi.call('get_messages',{'chat_id':chatId,'limit':50});
      if(serial!=requestSerial||!mounted)return;
      final list=(d['messages']??d['data']?['messages']??[]) as List;
      setState(()=>messages=list.map((e)=>Map<String,dynamic>.from(e)).toList());
      if(messages.isNotEmpty) {
        final last=int.tryParse('${messages.last['id']}')??0;
        await SturkApi.call('mark_read',{'chat_id':chatId,'up_to_id':last});
      }
    }catch(e){if(mounted&&!silent)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> send() async {
    final text=input.text.trim(); if(text.isEmpty||sending)return;
    setState(()=>sending=true);
    try {
      await SturkApi.call('send_message',{'chat_id':chatId,'content':text,'type':'text'});
      input.clear(); await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>sending=false);}
  }
  bool mine(Map<String,dynamic> m)=>'${m['sender_id']}'=='${widget.myUserId}';
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const Text('чат',style:TextStyle(fontSize:11,color:textMuted))]),leading:IconButton(icon:const Icon(Icons.arrow_back_rounded),onPressed:()=>Navigator.pop(context))),
    body:Column(children:[
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):ListView.builder(controller:scroll,padding:const EdgeInsets.fromLTRB(12,10,12,16),itemCount:messages.length,itemBuilder:(context,i){
        final m=messages[i]; final isMine=mine(m); final content=(m['content']??m['text']??'').toString();
        final status=(m['status']??'sent').toString();
        return Align(alignment:isMine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*.82),margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.fromLTRB(13,10,11,7),decoration:BoxDecoration(color:isMine?const Color(0xFF2B5278):panel,borderRadius:BorderRadius.only(topLeft:const Radius.circular(17),topRight:const Radius.circular(17),bottomLeft:Radius.circular(isMine?17:5),bottomRight:Radius.circular(isMine?5:17))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Align(alignment:Alignment.centerLeft,child:Text(content,style:const TextStyle(color:textMain,fontSize:15))),
          const SizedBox(height:4),Row(mainAxisSize:MainAxisSize.min,children:[Text(_time(m['created_at']),style:const TextStyle(color:Color(0xFFB7C5D3),fontSize:10)),if(isMine)Padding(padding:const EdgeInsets.only(left:4),child:Text(status=='read'?'✓✓':status=='delivered'?'✓✓':'✓',style:TextStyle(color:status=='read'?const Color(0xFF6AB2F2):const Color(0xFFB7C5D3),fontSize:12,fontWeight:FontWeight.bold)))])
        ])));
      })),
      Container(padding:const EdgeInsets.fromLTRB(10,8,10,12),decoration:const BoxDecoration(color:panel,border:Border(top:BorderSide(color:Color(0x1AFFFFFF)))),child:Row(children:[
        Expanded(child:TextField(controller:input,minLines:1,maxLines:5,textInputAction:TextInputAction.send,onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:'Сообщение',contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:12),filled:true,fillColor:panel2,border:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:BorderSide.none)))),
        const SizedBox(width:8),IconButton.filled(onPressed:sending?null:send,style:IconButton.styleFrom(backgroundColor:accent),icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send_rounded))
      ]))
    ]));
}
String _time(dynamic value){
  final n=int.tryParse('$value'); if(n==null)return '';
  final dt=DateTime.fromMillisecondsSinceEpoch(n*1000).toLocal();
  return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}
