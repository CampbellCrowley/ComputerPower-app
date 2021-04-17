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
  Navigator.popUntil(context, (route) => route.isFirst);
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
      home: MyHomePage(title: 'Computer Power Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  State<StatefulWidget> createState() => _HomePage();
}

class _HomePage extends State<MyHomePage> {
  bool _initialized = false;
  bool _error = false;
  bool _loading = false;
  User user;

  void initilizeFlutterFire() async {
    try {
      await Firebase.initializeApp();
      setState(() => _initialized = true);
      FirebaseAuth.instance.authStateChanges().listen((User myUser) {
        setState(() => user = myUser);
      });
    } catch (e) {
      setState(() => _error = true);
      print(e);
    }
  }

  @override
  void initState() {
    initilizeFlutterFire();
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

    if (user == null) {
      return _SignInView();
    } else {
      return _MainView(user);
    }
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

class _MainView extends StatelessWidget {
  _MainView(this.user);

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main View'),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Hello World!',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              'Welcome ${user.displayName}!',
            ),
          ],
        ),
      ),
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
