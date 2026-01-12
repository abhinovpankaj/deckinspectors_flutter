import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:E3InspectionsMultiTenant/src/ui/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../resources/couchbase/couchbase_services.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  //final _formKey = GlobalKey<FormState>();
  bool showPassword = false;
  bool isLoading = false;

  late CouchbaseServices couchbaseServices;

  @override
  void initState() {
    super.initState();
  }

  // Sign In Function
  Future<void> registerUser() async {
    couchbaseServices = Provider.of<CouchbaseServices>(context, listen: false);
    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty) {
      setState(() {
        isLoading = true;
      });
      var registerResult = await usersBloc.register(
          _usernameController.text,
          _passwordController.text,
          _firstNameController.text,
          _lastNameController.text,
          _emailController.text);

      setState(() {
        isLoading = false;
      });
      if (registerResult.insertedId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User registration failed,please retry.')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User registered successfully,please login now.')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all the details.')));
      return;
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
        )),
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
                    const SizedBox(
                      height: 4,
                    ),
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
                        // Text(
                        //   'First Name',
                        //   style: GoogleFonts.inter(
                        //     fontSize: 14.0,
                        //     color: Colors.black,
                        //     height: 1.0,
                        //   ),
                        // ),
                        const SizedBox(
                          height: 4,
                        ),
                        textField('Enter first name', _firstNameController),
                        const SizedBox(
                          height: 8,
                        ),
                        // Text(
                        //   'Last Name',
                        //   style: GoogleFonts.inter(
                        //     fontSize: 14.0,
                        //     color: Colors.black,
                        //     height: 1.0,
                        //   ),
                        // ),
                        const SizedBox(
                          height: 8,
                        ),
                        textField('Enter last name', _lastNameController),
                        // Text(
                        //   'Username',
                        //   style: GoogleFonts.inter(
                        //     fontSize: 14.0,
                        //     color: Colors.black,
                        //     height: 1.0,
                        //   ),
                        // ),
                        const SizedBox(
                          height: 8,
                        ),
                        textField('Enter email id', _emailController),

                        const SizedBox(
                          height: 16,
                        ),
                        textField('Enter username', _usernameController)
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    //password textField
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Text(
                        //   'Password',
                        //   style: GoogleFonts.inter(
                        //     fontSize: 14.0,
                        //     color: Colors.black,
                        //     height: 1.0,
                        //   ),
                        // ),
                        const SizedBox(
                          height: 8,
                        ),
                        passwordTextField(size),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // Padding(
                    //     padding: const EdgeInsets.fromLTRB(0, 70, 0, 0),
                    //     child: InkWell(
                    //         onTap: () => registerUser(),
                    //         child: const Align(
                    //             alignment: Alignment.centerRight,
                    //             child: Text(
                    //               'Login',
                    //               style: TextStyle(color: Colors.blue),
                    //             ))))
                  ],
                ),
              ),
              //sign in button section
              SizedBox(
                width: 400,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(8.0)),
                  icon: isLoading
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
                  label: const Text('Register Me'),
                ),
              ),
              //sign up text here
              const Expanded(flex: 1, child: Center()),
            ],
          ),
        ),
      ),
    ));
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
            text: 'REGI',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: 'STER',
            style: TextStyle(
              color: Color(0xFFFE9879),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget textField(String hintText, TextEditingController controller) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(
          fontSize: 18.0,
          color: const Color(0xFF151624),
        ),
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        cursorColor: const Color(0xFF151624),
        decoration: InputDecoration(
          hintText: hintText,
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
    );
  }

  Widget passwordTextField(Size size) {
    return SizedBox(
      height: 50,
      child: Stack(alignment: Alignment.centerRight, children: [
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
            )),
        InkWell(
            onTap: () => {
                  setState(() {
                    showPassword = !showPassword;
                  })
                },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.remove_red_eye_outlined),
            )),
      ]),
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
                border: Border.all(
                  width: 0.7,
                  color: const Color(0xFFD0D0D0),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
                child: Text(
              'Remember me',
              style: TextStyle(
                  color: Color(0xFF21899C),
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
            )),
          ],
        ));
  }

  Widget signInButton(Size size) {
    return InkWell(
        onTap: () {
          registerUser();
        },
        child: Container(
          alignment: Alignment.center,
          height: size.height / 15,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: const Color(0xFF21899C),
          ),
          child: Text(
            'Register Me',
            style: GoogleFonts.inter(
              fontSize: 14.0,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ));
  }
}
