import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';


void main() {
  runApp(MyApp());
}

void signOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MyHomePage()));
}

SharedPreferences? prefs;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Computer Power',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title = 'Computer Power Home Page';

  @override
  State<StatefulWidget> createState() => _HomePage();
}

class _HomePage extends State<MyHomePage> {
  bool _initialized = false;
  bool _error = false;
  bool _loading = false;

  void initializeFlutterFire() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs?.getBool('notifications_enabled') == null) {
      prefs?.setBool('notifications_enabled', true);
    }
    try {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() => _initialized = true);
      FirebaseAuth.instance.authStateChanges().listen((User? myUser) {
        if (myUser != null) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => _MainView(myUser)));
        }
      });

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'power_state_channel',
          'Power State Notifications',
          description: 'This channel is used to communicate changes in device power states.',
          importance: Importance.max);

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      final InitializationSettings initializationSettings =
          InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      flutterLocalNotificationsPlugin.initialize(initializationSettings);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('notifications_enabled') ?? false)) return;

        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: android.smallIcon,
                ),
              ));
        }
      });
    } catch (e) {
      setState(() => _error = true);
      print(e);
    }
  }

  @override
  void initState() {
    initializeFlutterFire();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Text('Failed to initialize.'),
      );
    }
    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Text('Initializing...'),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Text('Loading...'),
      );
    }

    return _SignInView();
  }
}

class _SignInView extends StatelessWidget {
  void signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      print('Successfully signed in with Google.');
    } catch (err) {
      print('Error signing in with Google');
      print(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Sign In.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SignInButton(Buttons.Google, onPressed: signInWithGoogle),
          ],
        ),
      ),
    );
  }
}

class _MainView extends StatefulWidget {
  _MainView(this.user);

  final User user;

  @override
  State<StatefulWidget> createState() => _MainState();
}

class _MainState extends State<_MainView> {
  _MainState();

  String? selectedComputer;
  List deviceList = [];
  Map? deviceInfo;
  String? responseMessage;

  final Map resetButton = {"button": 'reset'};
  final Map powerButton = {"button": 'power'};

  Future<bool> sendCommand(String cmd, Map body) async {
    print('Sending command $cmd: ${jsonEncode(body)}');
    return widget.user.getIdToken().then((token) {
      http.Client client = http.Client();
      return client.post(
          Uri.parse(
              'https://dev.campbellcrowley.com/pc2/api/$cmd/$selectedComputer'),
          headers: {'Authorization': token!, 'Content-type': 'application/json'},
          body: jsonEncode(body));
    }).then((res) {
      print('$cmd response: ${res.body}');
      if (res.statusCode == 200) {
        setState(() {
          responseMessage = '$cmd succeeded!';
        });
        return true;
      } else {
        setState(() {
          responseMessage = '$cmd failed!\n${res.body}';
        });
        return false;
      }
    });
  }

  Future<List> fetchDeviceList() async {
    return widget.user.getIdToken().then((token) {
      http.Client client = http.Client();
      return client.get(
          Uri.parse('https://dev.campbellcrowley.com/pc2/api/get-devices'),
          headers: {'Authorization': token!});
    }).then((res) {
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        // print(parsed);
        return parsed["data"];
      } else {
        return [];
      }
    });
  }

  Future<Map?> fetchDeviceInfo(String did) async {
    return widget.user.getIdToken().then((token) {
      http.Client client = http.Client();
      return client.get(
          Uri.parse('https://dev.campbellcrowley.com/pc2/api/get-info/$did'),
          headers: {'Authorization': token!});
    }).then((res) {
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        setState(() {
          responseMessage =
              'Data Updated\n${DateTime.now().toString().split('.')[0]}';
        });
        // print(parsed);
        return parsed["data"];
      } else {
        setState(() {
          responseMessage = 'Failed to fetch device info!\n${res.body}';
        });
        return null;
      }
    });
  }

  @override
  void initState() {
    fetchDeviceList().then((dList) {
      setState(() {
        deviceList = dList;
      });
      if (selectedComputer == null && dList.length > 0) {
        selectComputer(context, dList[0]["dId"], pop: false);
      }
    });

    new Timer.periodic(Duration(seconds: 10), (t) {
      fetchDeviceInfo(selectedComputer ?? '').then((dInfo) {
        setState(() {
          deviceInfo = dInfo;
        });
      });
    });

    super.initState();
  }

  void selectComputer(BuildContext context, String did, {bool pop = true}) {
    fetchDeviceInfo(did).then((dInfo) {
      setState(() {
        selectedComputer = did;
      });
      deviceInfo = dInfo;
      if (pop) Navigator.pop(context);
    });
  }

  List<Widget> getDrawerChildren(BuildContext context) {
    List<Widget> drawer = [
      DrawerHeader(
        child: Text('${widget.user.displayName}\'s Computers',
            style: Theme.of(context).textTheme.headlineMedium),
        decoration: BoxDecoration(
          color: Colors.blue,
          image: DecorationImage(
              image: NetworkImage(widget.user.photoURL ?? ''), fit: BoxFit.cover),
        ),
      ),
    ];
    for (int i = 0; i < deviceList.length; i++) {
      Map el = deviceList[i];
      drawer.add(
        ListTile(
          title: Text(el["dName"]),
          onTap: () => selectComputer(context, el["dId"]),
          tileColor:
              el["dId"] == selectedComputer ? Colors.lightBlue : Colors.white,
        ),
      );
    }
    return drawer;
  }

  String stateToString(int state) {
    switch (state) {
      case 0:
        return 'Off';
      case 1:
        return 'On';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    Map? comp = deviceInfo;
    Map? meta;
    try {
      meta = deviceList
          .firstWhere((element) => element["dId"] == selectedComputer);
    } catch (err) {
      // Not found.
    }
    List<MapEntry<int, dynamic>> data = (comp != null
            ? comp["summary"]
            : <double>[1, 0.8, 0.6, 0.4, 0.2, 0.1, 0])
        .asMap()
        .entries
        .toList();
    // print(data);
    List<Series<MapEntry, String>> seriesList = [
      new Series<MapEntry, String>(
          id: '% Uptime',
          domainFn: (MapEntry el, _) {
            final List<String> days = [
              "Sun",
              "Mon",
              "Tue",
              "Wed",
              "Thu",
              "Fri",
              "Sat"
            ];
            // print('Domain: ${el}: ${days[el.key]}');
            return '${days[el.key]}';
          },
          measureFn: (MapEntry el, _) {
            // print('Measure: ${el.value}');
            return max(min(el.value * 100, 100), 0);
          },
          data: data)
    ];

    final int curState = comp == null ? -1 : comp["currentState"];

    return Scaffold(
      appBar: AppBar(
        title: Text(meta != null ? meta["dName"] : 'No Device'),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _SettingsView()),
                );
              },
              icon: Icon(Icons.settings)),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  meta == null ? '...' : meta["dName"],
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ' is currently ',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            Container(
              color: comp == null
                  ? Colors.grey
                  : (comp["currentState"] == 0
                      ? Colors.red
                      : (comp["currentState"] == 1
                          ? Colors.green
                          : Colors.grey)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    comp != null
                        ? stateToString(comp["currentState"])
                        : 'Unknown',
                    style: Theme.of(context).textTheme.displaySmall,
                  )
                ],
              ),
            ),
            Container(
              color: Colors.black,
              height: 4,
            ),
            Container(
              height: 200.0,
              child: BarChart(seriesList, animate: true),
            ),
            Container(
              color: Colors.black,
              height: 4,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text(curState == 0 ? 'Turn On' : 'Turn Off'),
                  onPressed: () => sendCommand(
                      'request-state', {"state": curState == 0 ? 1 : 0}),
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                          curState == 0 ? Colors.green : Colors.red)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text('Press Power'),
                  onPressed: () => sendCommand('press-button', powerButton),
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.green)),
                ),
                ElevatedButton(
                  child: Text('Hold Power'),
                  onPressed: () => sendCommand('hold-button', powerButton),
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(Colors.lightGreen)),
                ),
                ElevatedButton(
                  child: Text('Press Reset'),
                  onPressed: () => sendCommand('press-button', resetButton),
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(Colors.orange)),
                ),
              ],
            ),
            Container(
              color: Colors.black,
              height: 4,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    responseMessage ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      drawer: Drawer(
          child: ListView(
        padding: EdgeInsets.zero,
        children: getDrawerChildren(context),
      )),
    );
  }
}

class _SettingsView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SettingsState();
  }
}

class _SettingsState extends State<_SettingsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
        ),
        body: ListView(
          children: [
            ListTile(
              subtitle: ElevatedButton(
                child: Text('Sign Out'),
                onPressed: () => signOut(context),
              ),
            ),
            SwitchListTile(
                title: const Text('Notifications Enabled'),
                value: prefs?.getBool('notifications_enabled') ?? false,
                onChanged: (bool value) {
                  print('Toggled notifications ' + (value ? 'On' : 'Off'));
                  setState(() {
                    prefs?.setBool('notifications_enabled', value);
                  });
                }),
            ListTile(
              subtitle: ElevatedButton(
                child: Text('Test Notification'),
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  if (!(prefs.getBool('notifications_enabled') ?? false)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Notifications disabled!')));
                  } else {
                    final FlutterLocalNotificationsPlugin
                        flutterLocalNotificationsPlugin =
                        FlutterLocalNotificationsPlugin();
                    const AndroidNotificationChannel channel =
                        AndroidNotificationChannel(
                            'power_state_channel',
                            'Power State Notifications',
                            description: 'This channel is used to communicate changes in device power states.',
                            importance: Importance.max);
                    await flutterLocalNotificationsPlugin
                        .resolvePlatformSpecificImplementation<
                            AndroidFlutterLocalNotificationsPlugin>()
                        ?.createNotificationChannel(channel);
                    flutterLocalNotificationsPlugin.show(
                        0,
                        'Test Notification!',
                        'Notifications will appear here as your devices change power state!',
                        NotificationDetails(
                            android: AndroidNotificationDetails(
                          channel.id,
                          channel.name,
                          channelDescription: channel.description,
                        )));
                  }
                },
              ),
            ),
          ],
        ));
  }
}
