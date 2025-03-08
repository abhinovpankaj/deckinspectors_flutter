// import 'package:flutter/material.dart';
// import 'package:realm/realm.dart';

// import '../../app.dart';

// class AppServices with ChangeNotifier {
//   String id;
//   Uri baseUrl;
//   App app;
//   User? currentUser;
//   AppServices(this.id, this.baseUrl)
//       : app = App(AppConfiguration(id, baseUrl: baseUrl));

//   Future<User> logInUserEmailPassword(String email, String password) async {
//     User loggedInUser =
//         await app.logIn(Credentials.emailPassword(email, password));
//     currentUser = loggedInUser;
//     notifyListeners();
//     return loggedInUser;
//   }

//   Future<User> logInAnonymously() async {
//     final loggedInUser = await app.logIn(Credentials.anonymous());
//     currentUser = loggedInUser;
//     notifyListeners();
//     return loggedInUser;
//   }

//   Future<User?> registerUserEmailPassword(String email, String password) async {
//     EmailPasswordAuthProvider authProvider = EmailPasswordAuthProvider(app);
//     User? loggedInUser;
//     try {
//       loggedInUser =
//           await app.logIn(Credentials.emailPassword(email, password));
//     } catch (e) {
//       await authProvider.registerUser(email, password);
//     }
//     currentUser = loggedInUser;
//     notifyListeners();
//     return loggedInUser;
//   }

//   void notifyinCaseofOfflineMode() {
//     notifyListeners();
//   }

// // Future<void> setRole(User loggedInUser) async {
// //     final realm = Realm(Configuration.flexibleSync(loggedInUser, [Role.schema, Item.schema]));
// //     String subscriptionName = "rolesSubscription";
// //     realm.subscriptions.update((mutableSubscriptions) => mutableSubscriptions.add(realm.all<Role>(), name: subscriptionName));
// //     await realm.subscriptions.waitForSynchronization();
// //     realm.write(() => realm.add(Role(ObjectId(), loggedInUser.id, isAdmin: false)));
// //     await realm.syncSession.waitForUpload();
// //     realm.subscriptions.update((mutableSubscriptions) => mutableSubscriptions.removeByName(subscriptionName));
// //     await realm.subscriptions.waitForSynchronization();
// //     await realm.syncSession.waitForDownload();
// //     realm.close();
// //   }
//   Future<void> logOut() async {
//     await currentUser?.logOut();
//     currentUser = null;
//   }

//   void registerUser(String email, String password) async {
//     EmailPasswordAuthProvider authProvider = EmailPasswordAuthProvider(app);
//     await authProvider.registerUser(email, password);
//   }
// }
