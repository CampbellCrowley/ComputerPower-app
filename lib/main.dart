import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:charts_flutter/flutter.dart';

void main() {
  runApp(MyApp());
}

void signOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MyHomePage()));
}

Future<bool> sendCommand(String cmd) async {
  // TODO: Implement sending command to server.
  return false;
}

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
    try {
      await Firebase.initializeApp();
      setState(() => _initialized = true);
      FirebaseAuth.instance.authStateChanges().listen((User myUser) {
        if (myUser != null) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => _MainView(myUser)));
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
      final GoogleSignInAccount googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final GoogleAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
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
              style: Theme.of(context).textTheme.headline4,
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

  int selectedComputer = 0;

  // TODO: Temporary example data until I fetch from the API.
  final List<Map> computerData = [
    {
      "id": 0,
      "name": 'My Desktop #1',
      "currentState": "On",
      "previousStateChange": "Mon 04-26 07:56:16",
      "now": "Mon Apr 26 2021 14:37:07 GMT-0800 (AKDT)",
      "history": <double>[55.32, 62.74, 61.84, 60.12, 69.36, 56.75, 67.28]
    },
    {
      "id": 1,
      "name": 'My Desktop #2',
      "currentState": "On",
      "previousStateChange": "Mon 04-26 07:56:16",
      "now": "Mon Apr 26 2021 14:37:07 GMT-0800 (AKDT)",
      "history": <double>[55.32, 62.74, 61.84, 60.12, 69.36, 56.75, 67.28]
    },
    {
      "id": 2,
      "name": 'My Desktop #3',
      "currentState": "On",
      "previousStateChange": "Mon 04-26 07:56:16",
      "now": "Mon Apr 26 2021 14:37:07 GMT-0800 (AKDT)",
      "history": <double>[55.32, 62.74, 61.84, 60.12, 69.36, 56.75, 67.28]
    }
  ];

  @override
  void initState() {
    if (widget.user == null) {
      Future(() => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MyHomePage())));
    }
    super.initState();
  }

  void selectComputer(BuildContext context, int index) {
    setState(() {
      selectedComputer = index;
    });
    Navigator.pop(context);
  }

  List<Widget> getDrawerChildren(BuildContext context) {
    List<Widget> drawer = [
      DrawerHeader(
        child: Text('${widget.user.displayName}\'s Computers',
            style: Theme.of(context).textTheme.headline4),
        decoration: BoxDecoration(
          color: Colors.blue,
          image: DecorationImage(
              image: NetworkImage(widget.user.photoURL), fit: BoxFit.cover),
        ),
      ),
    ];
    for (int i = 0; i < computerData.length; i++) {
      Map el = computerData[i];
      drawer.add(
        ListTile(
          title: Text(el["name"]),
          onTap: () => selectComputer(context, i),
          tileColor: i == selectedComputer ? Colors.lightBlue : Colors.white,
        ),
      );
    }
    return drawer;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Text("Unknown user...");
    }
    Map comp = computerData[selectedComputer];
    List<MapEntry<int, double>> data = comp["history"].asMap().entries.toList();
    // print(data);
    List<Series<MapEntry, String>> seriesList = [
      new Series<MapEntry, String>(
          id: 'Power Percentage',
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
            return el.value;
          },
          data: data)
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(comp["name"]),
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
            Container(
              height: 200.0,
              child: BarChart(seriesList, animate: true),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text('Press Power'),
                  onPressed: () => sendCommand('press-power'),
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.green)),
                ),
                ElevatedButton(
                  child: Text('Hold Power'),
                  onPressed: () => sendCommand('hold-power'),
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.lightGreen)),
                ),
                ElevatedButton(
                  child: Text('Press Reset'),
                  onPressed: () => sendCommand('press-reset'),
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.orange)),
                ),
              ],
            ),
            Text(
              'Current State: ${comp["currentState"]}',
              style: Theme.of(context).textTheme.subtitle1,
            ),
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

class _SettingsView extends StatelessWidget {
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
          ],
        ));
  }
}
