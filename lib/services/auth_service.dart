import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Get current user's display name
  Future<String?> getCurrentUserName() async {
    if (currentUser == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return doc.data()?['displayName'] ?? currentUser!.email?.split('@')[0];
      }
      return currentUser!.displayName ?? currentUser!.email?.split('@')[0];
    } catch (e) {
      return currentUser!.email?.split('@')[0];
    }
  }
  
  // Get user name by email
  Future<String?> getUserNameByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['displayName'];
      }
      return email.split('@')[0];
    } catch (e) {
      return email.split('@')[0];
    }
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last seen (with permission error handling)
      if (userCredential.user != null) {
        try {
          await _firestore.collection('users').doc(userCredential.user!.uid).update({
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Try to create the document if it doesn't exist
          try {
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid,
              'email': email,
              'displayName': userCredential.user!.displayName ?? email.split('@')[0],
              'lastSeen': FieldValue.serverTimestamp(),
            });
          } catch (permissionError) {
            // Silently handle permission errors - user can still use the app
            print('Note: Could not update user profile. Please check Firestore rules.');
          }
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        // Update display name in Firebase Auth
        await userCredential.user!.updateDisplayName(displayName);
        
        // Store user data in Firestore (with permission error handling)
        try {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email,
            'displayName': displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } catch (permissionError) {
          // Silently handle permission errors - user can still use the app
          print('Note: Could not create user profile. Please check Firestore rules.');
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}
