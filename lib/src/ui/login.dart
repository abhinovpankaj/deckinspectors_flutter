import 'dart:io';
//import 'dart:math';

import 'package:E3InspectionsMultiTenant/src/bloc/settings_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/models/login_response.dart';
import 'package:E3InspectionsMultiTenant/src/ui/home.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  //final _formKey = GlobalKey<FormState>();
  bool showPassword = false;
  bool isLoading = false;
  bool? _isChecked = false;
  //late AppServices appServices;
  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('username') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      _isChecked = prefs.getBool('isChecked') ?? false;
    });
  }

  bool activeConnection = false;
  String T = "";
  Future checkUserConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        activeConnection = true;
        //start upload process
      }
    } on SocketException catch (_) {
      activeConnection = false;
    }
    appSettings.activeConnection = activeConnection;
  }

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<String?> _getId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.id +
          androidDeviceInfo.host; // unique ID on Android
    }
    return null;
  }

  // Sign In Function
  Future<void> login() async {
    //appServices = Provider.of<AppServices>(context, listen: false);
    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      setState(() {
        isLoading = true;
      });
      //check if no connectivity
      await checkUserConnection();
      await appSettings.initConnectivity();
      LoginResponse loginResult;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = await _getId() as String;
      if (activeConnection) {
        loginResult = await usersBloc.login(
          _usernameController.text,
          _passwordController.text,
          deviceId,
        );

        if (_isChecked == true && loginResult.firstname != null) {
          await prefs.setString('username', _usernameController.text);
          await prefs.setString('password', _passwordController.text);
          await prefs.setBool('isChecked', _isChecked as bool);
          await prefs.setString('firstname', loginResult.firstname as String);
          await prefs.setString('lastname', loginResult.lastname as String);
        }
      } else {
        var fName = prefs.getString('firstname') ?? '';
        var lName = prefs.getString('lastname') ?? '';
        loginResult = LoginResponse(
          username: _usernameController.text,
          accesstype: 'mobile',
          firstname: fName,
          lastname: lName,
        );
        usersBloc.userDetails = loginResult;
        if (fName.isEmpty && _usernameController.text.isEmpty) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please login once in online mode,offline user details are missing.',
              ),
            ),
          );
        }
      }

      setState(() {
        isLoading = false;
      });
      if (loginResult.username == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed,please check your credentials.'),
          ),
        );
        return;
      }
      if (loginResult.username == 'loggedin') {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loginResult.token as String)));
        return;
      }
      if (loginResult.username!.isNotEmpty && loginResult.accesstype != "web") {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed,please check your access.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          alignment: Alignment.center,
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(33, 137, 156, 0.15),
                Colors.white,
                Colors.white,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                //to give space from top
                const Expanded(flex: 1, child: Center()),
                //logo and text section
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      logo(size.height / 8, size.height / 4),
                      richText(16),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                //email and password textField section
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      //email textField
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Username',
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: Colors.black,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          emailTextField(size),
                        ],
                      ),

                      const SizedBox(height: 16),

                      //password textField
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: Colors.black,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          passwordTextField(size),
                        ],
                      ),

                      const SizedBox(height: 12),

                      //keep signed in and forget password section
                      rememberMe(),
                      // Padding(
                      //     padding: const EdgeInsets.fromLTRB(0, 70, 0, 0),
                      //     child: InkWell(
                      //         onTap: () => registerUser(),
                      //         child: const Align(
                      //             alignment: Alignment.centerRight,
                      //             child: Text(
                      //               'Don\'t have account,Register',
                      //               style: TextStyle(color: Colors.blue),
                      //             ))))
                    ],
                  ),
                ),
                //sign in button section
                SizedBox(
                  width: 400,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(8.0),
                    ),
                    icon:
                        isLoading
                            ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(4.0),
                              child: const CircularProgressIndicator(
                                color: Colors.blue,
                                strokeWidth: 3,
                              ),
                            )
                            : const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ),
                //sign up text here
                const Expanded(flex: 1, child: Center()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget logo(double height_, double width_) {
    return Image.asset(
      'assets/images/icon.png',
      height: height_,
      width: width_,
    );
  }

  Widget richText(double fontSize) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.inter(
          fontSize: 20.0,
          color: const Color(0xFF21899C),
          letterSpacing: 2,
        ),
        children: const [
          TextSpan(
            text: 'LOGIN',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: 'PAGE',
            style: TextStyle(
              color: Color(0xFFFE9879),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget emailTextField(Size size) {
    return SizedBox(
      height: size.height / 15,
      child: TextField(
        controller: _usernameController,
        style: GoogleFonts.inter(
          fontSize: 18.0,
          color: const Color(0xFF151624),
        ),
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        cursorColor: const Color(0xFF151624),
        decoration: InputDecoration(
          hintText: 'Enter your username',
          hintStyle: GoogleFonts.inter(
            fontSize: 14.0,
            color: const Color(0xFFABB3BB),
            height: 1.0,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget passwordTextField(Size size) {
    return SizedBox(
      height: size.height / 15,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextField(
            obscureText: !showPassword,
            controller: _passwordController,
            style: GoogleFonts.inter(
              fontSize: 18.0,
              color: const Color(0xFF151624),
            ),
            maxLines: 1,
            keyboardType: TextInputType.emailAddress,
            cursorColor: const Color(0xFF151624),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.0,
                color: const Color(0xFFABB3BB),
                height: 1.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          InkWell(
            onTap:
                () => {
                  setState(() {
                    showPassword = !showPassword;
                  }),
                },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.remove_red_eye_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget rememberMe() {
    return Transform.scale(
      scale: 1.1,
      child: CheckboxListTile(
        title: const Text(
          'Remember me',
          style: TextStyle(color: Color(0xFF21899C)),
        ),
        value: _isChecked,
        visualDensity: VisualDensity.compact,
        checkColor: const Color(0xFFFFFFFF),
        controlAffinity: ListTileControlAffinity.leading,
        checkboxShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
        ),
        onChanged: (value) {
          setState(() {
            _isChecked = value;
          });
        },
      ),
    );
  }

  Widget keepSignedForgetSection() {
    return InkWell(
      onTap: () {},
      child: Row(
        children: <Widget>[
          Container(
            width: 24.0,
            height: 24.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(width: 0.7, color: const Color(0xFFD0D0D0)),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Remember me',
              style: TextStyle(
                color: Color(0xFF21899C),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget signInButton(Size size) {
    return InkWell(
      onTap: () {
        login();
      },
      child: Container(
        alignment: Alignment.center,
        height: size.height / 15,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: const Color(0xFF21899C),
        ),
        child: Text(
          'Sign In',
          style: GoogleFonts.inter(
            fontSize: 14.0,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildFooter(Size size) {
    return Center(
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.inter(fontSize: 12.0, color: Colors.black),
          children: const [
            TextSpan(
              text: 'Don’t have an account? ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: 'Sign Up here',
              style: TextStyle(
                color: Color(0xFFFF7248),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // registerUser() {
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (context) => const RegisterPage()),
  //   );
  // }
}
